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

  test "event time control renders a timestamp tooltip and metadata scrolls in a code block" do
    sign_in @user
    event = RecordingStudio::Event.order(occurred_at: :desc).first
    formatted = event.occurred_at.strftime("%e %b %Y %l:%M%P")

    get events_path

    assert_response :success
    assert_select "time.flat-pack-timestamp", text: /ago/
    assert_includes response.body, formatted
    assert_select "td.whitespace-nowrap"
    assert_select "pre.overflow-x-auto"
    refute_match "flat-pack--popover", response.body
  end

  test "events nav is a real link from home" do
    sign_in @user
    get root_path
    assert_response :success
    assert_select "a[href=?]", events_path, text: /Events/

    get events_path
    assert_response :success
    assert_select "h1", count: 1, text: "Events"
    assert_match "Events", response.body
    assert_select "a[href=?]", root_path, text: /Home/
  end

  test "signed in home lists orderable pages and not a sidebar shell" do
    sign_in @user
    get root_path

    assert_response :success
    assert_select "h1", count: 1, text: "Order demo"
    assert_select "body[data-recording-studio-default-layout='true']"
    assert_match "Order demo", response.body
    assert_match "Mix Notes", response.body
    assert_match "Move down", response.body
    assert_equal ["0", "1"], position_cells("order-demo-table")
    assert_select "[data-modal-id=?]", "reorder-pages-modal", text: "Reorder in modal"
    assert_select "a[href=?][aria-current=?]", root_path, "page", text: /Home/
    assert_select "a[href=?]", events_path, text: /Events/
    assert_select "[data-controller~=?][data-action*=?]", "order-refresh", "order-refresh#refresh"
    refute_match "flat_pack_sidebar", response.body
    refute_match "Setup", response.body
  end

  test "reorder modal lists draggable pages and the reorder endpoint persists that order" do
    sign_in @user
    pages = @folder_recording.recording_studio_orderable_children.to_a
    reversed = pages.reverse.map(&:id)

    get root_path

    assert_response :success
    assert_select "#reorder-pages-modal[data-controller~=?]", "flat-pack--modal"
    assert_select "#reorder-pages-modal [data-controller~=?]", "flat-pack--table-sortable"
    assert_select "#reorder-pages-modal [data-flat-pack--table-sortable-reorder-url-value=?]", reorder_pages_path
    assert_select "#reorder-pages-modal [data-flat-pack--table-sortable-target=?]", "row", count: pages.length
    assert_select "#reorder-pages-modal [data-flat-pack--icon-name-value=?]", "bars-3", count: pages.length
    assert_equal pages.map { |page| page.recording_studio_orderable_position.to_s }, position_cells("reorder-pages-modal")
    reversed.each do |recording_id|
      assert_match(/\A[0-9a-f-]{36}\z/i, recording_id)
      assert_select "#reorder-pages-modal [data-id=?]", recording_id
    end
    refute_match(/page-reorder/, response.body)

    patch reorder_pages_path, params: {
      reorder: {
        resource: "pages",
        strategy: "dense_integer",
        items: reversed.each_with_index.map { |recording_id, index| { id: recording_id, position: index + 1 } }
      }
    }, as: :json

    assert_response :success
    children = @folder_recording.reload.recording_studio_orderable_children.to_a
    assert_equal reversed, children.map(&:id)
    assert_equal (0...children.length).to_a, children.map(&:recording_studio_orderable_position)
    event = @folder_recording.events(actions: ["reordered"]).order(occurred_at: :desc).first
    assert_equal "dummy_modal_reorder", event.metadata.to_h.stringify_keys["source"]
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

  def position_cells(container_id)
    headers = css_select("##{container_id} thead th").map { |header| header.text.strip }
    index = headers.index("position") || 0
    css_select("##{container_id} tbody tr").map { |row| row.css("td")[index].text.strip }
  end

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
