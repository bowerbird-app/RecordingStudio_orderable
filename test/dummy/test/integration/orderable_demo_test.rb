# frozen_string_literal: true

require "test_helper"

class OrderableDemoTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    Current.actor = @user
    seed_demo_tree!
  end

  test "login page uses a flatpack card" do
    get new_user_session_path

    assert_response :success
    assert_select "label", text: /Email/i
    assert_match "admin@admin.com", response.body
    assert_match "Sign In", response.body
  end

  test "compiled tailwind includes flatpack component utilities" do
    css_path = Rails.root.join("app/assets/builds/tailwind.css")
    assert File.exist?(css_path), "expected #{css_path} after bin/rails tailwindcss:build"
    assert_operator css_path.size, :>, 20_000, "expected scanned Flatpack utilities, got #{css_path.size} bytes"

    css = css_path.read
    assert_includes css, "inline-flex"
    assert_includes css, 'rounded-\\[var\\(--button'
    assert_includes css, 'bg-\\[var\\(--button'
    assert_includes css, 'min-w-\\[40rem'
  end

  test "events nav is a real link from home" do
    sign_in @user
    get root_path
    assert_response :success
    assert_select "a[href=?]", events_path, text: /Events/

    get events_path
    assert_response :success
    assert_match "Events", response.body
    assert_select "a[href=?]", root_path, text: /Home/
  end

  test "signed in home lists orderable pages and not a sidebar shell" do
    sign_in @user
    get root_path

    assert_response :success
    assert_match "Order demo", response.body
    assert_match "Mix Notes", response.body
    assert_match "Move down", response.body
    assert_select "a[href=?]", root_path, text: /Home/
    assert_select "a[href=?]", events_path, text: /Events/
    refute_match "flat_pack_sidebar", response.body
    refute_match "Setup", response.body
  end

  test "moving a page updates sibling position and writes an event" do
    sign_in @user
    moving = @folder_recording.recording_studio_orderable_children.to_a.last

    patch move_page_path(moving), params: { to_index: 0 }
    assert_redirected_to root_path

    @folder_recording.reload
    assert_equal moving.id, @folder_recording.recording_studio_orderable_children.first.id
    assert @folder_recording.events(actions: ["reordered"]).exists?
  end

  test "appending a page moves it to the end of the sibling list" do
    sign_in @user
    pages = @folder_recording.recording_studio_orderable_children.to_a
    moving = pages.first

    @folder_recording.recording_studio_orderable_append!(moving, actor: @user)

    assert_equal moving.id, @folder_recording.reload.recording_studio_orderable_children.last.id
    assert_equal pages.last.id, @folder_recording.recording_studio_orderable_children.first.id
  end

  test "appending the only page on an empty list keeps it as the sole child" do
    sign_in @user
    workspace_recording = RecordingStudio.root_recording_for(Workspace.first)
    empty_folder = find_or_record!(workspace_recording, Folder, "empty-order-folder") do |folder|
      folder.name = "Empty Order Folder"
      folder.slug = "empty-order-folder"
    end
    page_recording = find_or_record!(workspace_recording, Page, "solo-order-page", parent: empty_folder) do |page|
      page.title = "Solo Order Page"
      page.slug = "solo-order-page"
      page.body = "Dummy append empty list page"
    end

    empty_folder.recording_studio_orderable_append!(page_recording, actor: @user)

    children = empty_folder.reload.recording_studio_orderable_children.to_a
    assert_equal [page_recording.id], children.map(&:id)
    assert_equal 0, page_recording.reload.recording_studio_orderable_position
  end

  test "project does not receive the orderable capability" do
    refute RecordingStudio.capability_enabled?(:orderable, for: "Project")
    assert RecordingStudio.capability_enabled?(:orderable, for: "Folder")
  end

  test "move without a folder redirects" do
    sign_in @user
    Folder.delete_all

    patch move_page_path("missing"), params: { to_index: 0 }

    assert_redirected_to root_path
  end

  private

  def seed_demo_tree!
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    workspace_recording = RecordingStudio.root_recording_for(workspace)

    @project_recording = find_or_record!(workspace_recording, Project, "album-launch") do |project|
      project.name = "Album Launch"
      project.slug = "album-launch"
    end

    @folder_recording = find_or_record!(workspace_recording, Folder, "reference-assets", parent: @project_recording) do |folder|
      folder.name = "Reference Assets"
      folder.slug = "reference-assets"
    end

    %w[mix-notes release-checklist].each_with_index do |slug, index|
      page_recording = find_or_record!(workspace_recording, Page, slug, parent: @folder_recording) do |page|
        page.title = slug.tr("-", " ").split.map(&:capitalize).join(" ")
        page.slug = slug
        page.body = "Dummy integration page"
      end
      page_recording.update!(recording_studio_orderable_position: index)
    end
  end

  def find_or_record!(workspace_recording, type, slug, parent: workspace_recording, &)
    existing = DemoRecordingLookup.by_slug(type: type.name, slug: slug)
    return existing if existing

    workspace_recording.record(type, actor: @user, metadata: { seed: true }, parent_recording: parent, &)
  end
end
