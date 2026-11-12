# frozen_string_literal: true

require "test_helper"

class OrderableApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"

  setup do
    @previous_actor = Current.actor
    @owner = user("owner")
    @editor = user("editor")
    @viewer = user("viewer")
    @stranger = user("stranger")
    Current.actor = @owner
    @workspace = owned_root(Workspace.create!(name: "API Studio #{SecureRandom.hex(4)}"))
    @other = owned_root(Workspace.create!(name: "Other Studio #{SecureRandom.hex(4)}"), actor: @stranger)
    @folder = record_folder(@workspace, "api-folder")
    @pages = [
      record_page(@workspace, @folder, "page-a", "Page A"),
      record_page(@workspace, @folder, "page-b", "Page B"),
      record_page(@workspace, @folder, "page-c", "Page C")
    ]
    @pages.each_with_index do |page, index|
      page.update!(recording_studio_orderable_position: index)
    end
    @editor_access = grant!(@workspace, @editor, :edit)
    @viewer_access = grant!(@workspace, @viewer, :view)
    @editor_token, = token_for(@editor_access)
    @viewer_token, = token_for(@viewer_access)
  end

  teardown { Current.actor = @previous_actor }

  test "reorder with edit role returns the parent in the new sibling order" do
    ids = @pages.map(&:id).map(&:to_s).reverse

    body = call(:post, "/folders/#{@folder.id}/actions/reorder", @editor_token, ordered_recording_ids: ids)

    assert_response :success, response.body
    assert_equal @folder.id, body.fetch("id")
    assert_equal ids, @folder.reload.recording_studio_orderable_children.map { |child| child.id.to_s }
  end

  test "move_position with edit role moves one child" do
    moving = @pages.last

    body = call(
      :post,
      "/folders/#{@folder.id}/actions/move_position",
      @editor_token,
      recording_id: moving.id,
      to_index: 0
    )

    assert_response :success, response.body
    assert_equal @folder.id, body.fetch("id")
    assert_equal moving.id, @folder.reload.recording_studio_orderable_children.first.id
  end

  test "view role is forbidden from reorder and move_position" do
    call(:post, "/folders/#{@folder.id}/actions/reorder", @viewer_token, ordered_recording_ids: [@pages.last.id])
    assert_response :forbidden, response.body

    call(
      :post,
      "/folders/#{@folder.id}/actions/move_position",
      @viewer_token,
      recording_id: @pages.last.id,
      to_index: 0
    )
    assert_response :forbidden, response.body
  end

  test "a folder in another workspace is not found" do
    other_folder = record_folder(@other, "other-folder")

    call(:post, "/folders/#{other_folder.id}/actions/reorder", @editor_token, ordered_recording_ids: [@pages.first.id])
    assert_response :not_found, response.body

    call(
      :post,
      "/folders/#{other_folder.id}/actions/move_position",
      @editor_token,
      recording_id: @pages.first.id,
      to_index: 0
    )
    assert_response :not_found, response.body
  end

  test "bad reorder and move_position input is unprocessable" do
    call(:post, "/folders/#{@folder.id}/actions/reorder", @editor_token, ordered_recording_ids: "not-an-array")
    assert_response :unprocessable_entity, response.body

    snapshot = @folder.reload.recording_studio_orderable_children.map(&:id)
    call(
      :post,
      "/folders/#{@folder.id}/actions/move_position",
      @editor_token,
      recording_id: SecureRandom.uuid,
      to_index: 0
    )
    assert_response :unprocessable_entity, response.body
    assert_equal snapshot, @folder.reload.recording_studio_orderable_children.map(&:id)
  end

  test "folder update does not write sibling position" do
    before = @pages.map { |page| [page.id, page.reload.recording_studio_orderable_position] }

    call(
      :patch,
      "/folders/#{@folder.id}",
      @editor_token,
      recording_studio_orderable_position: 99
    )

    assert_response :success, response.body
    assert_nil @folder.reload.recording_studio_orderable_position

    call(
      :patch,
      "/pages/#{@pages.first.id}",
      @editor_token,
      recording_studio_orderable_position: 99
    )

    assert_response :success, response.body
    before.each do |id, position|
      assert_equal position, RecordingStudio::Recording.find(id).recording_studio_orderable_position
    end
  end

  test "orderable actions use the html authorization role and skip move" do
    reorder = RecordingStudioApi.capability_action(:reorder)
    move_position = RecordingStudioApi.capability_action(:move_position)
    folder = RecordingStudioApi.recordable_registration_for("Folder")

    assert_equal :orderable, reorder.capability
    assert_equal :edit, reorder.required_role
    assert_equal "Recording - Reorder", reorder.openapi.fetch(:summary)
    assert_equal false, reorder.input_contract.as_json.fetch(:reject_unknown)
    assert_equal :orderable, move_position.capability
    assert_equal :edit, move_position.required_role
    assert_equal "Recording - Move position", move_position.openapi.fetch(:summary)
    assert_equal %w[move_position reorder], Array(folder.capability_actions).map(&:to_s).sort
    refute_includes Array(folder.writable_attributes).map(&:to_s), "recording_studio_orderable_position"
    refute_includes Array(RecordingStudioApi.recordable_registration_for("Page").writable_attributes).map(&:to_s),
                    "recording_studio_orderable_position"
  end

  private

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def owned_root(recordable, actor: @owner)
    root = RecordingStudio.root_recording_for(recordable)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: actor)
    raise result.error if result.failure?

    root
  end

  def grant!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @owner
    )
    raise result.error if result.failure?

    result.value
  end

  def record_folder(workspace, slug)
    workspace.record(Folder, actor: Current.actor, parent_recording: workspace) do |folder|
      folder.name = slug.tr("-", " ").split.map(&:capitalize).join(" ")
      folder.slug = slug
    end
  end

  def record_page(workspace, folder, slug, title)
    workspace.record(Page, actor: Current.actor, parent_recording: folder) do |page|
      page.title = title
      page.slug = slug
      page.body = "API order fixture"
    end
  end

  def token_for(access_recording)
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_recording.parent_recording || access_recording.root_recording,
      manager_actor: @owner,
      role: access_recording.recordable.role,
      name: "Client #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    [issued.value.fetch(:access_token), provision.value.fetch(:api_client)]
  end

  def call(method, path, token, params = {})
    send(
      method,
      "#{BASE}#{path}",
      params: params,
      headers: {
        "Authorization" => "Bearer #{token}",
        "Accept" => "application/json"
      },
      as: :json
    )
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end
end
