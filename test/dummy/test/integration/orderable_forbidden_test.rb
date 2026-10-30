# frozen_string_literal: true

require "test_helper"

class OrderableForbiddenTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    Current.actor = @user
    @resolver_before = RecordingStudioOrderable.configuration.authorization_resolver
    seed_demo_tree!
  end

  teardown do
    RecordingStudioOrderable.configuration.authorization_resolver = @resolver_before
  end

  test "signed-in reorder denied by the resolver is forbidden" do
    sign_in @user
    RecordingStudioOrderable.configuration.authorization_resolver = ->(**) { false }

    patch reorder_pages_path, params: { ordered_recording_ids: [@page_recording.id.to_s] }

    assert_response :forbidden
  end

  test "engine controller maps NotAuthorized to forbidden" do
    handlers = RecordingStudioOrderable::ApplicationController.rescue_handlers

    assert handlers.any? { |name, _method| name == "RecordingStudioOrderable::NotAuthorized" }
  end

  private

  def seed_demo_tree!
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    workspace_recording = RecordingStudio.root_recording_for(workspace)

    folder_recording = find_or_record!(workspace_recording, Folder, "reference-assets", parent: workspace_recording) do |folder|
      folder.name = "Reference Assets"
      folder.slug = "reference-assets"
    end

    @page_recording = find_or_record!(workspace_recording, Page, "mix-notes", parent: folder_recording) do |page|
      page.title = "Mix Notes"
      page.slug = "mix-notes"
      page.body = "Dummy integration page"
    end
  end

  def find_or_record!(workspace_recording, type, slug, parent: workspace_recording, &)
    existing = DemoRecordingLookup.by_slug(type: type.name, slug: slug)
    return existing if existing

    workspace_recording.record(type, actor: @user, metadata: { seed: true }, parent_recording: parent, &)
  end
end