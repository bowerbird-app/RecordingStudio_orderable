# frozen_string_literal: true

require "test_helper"

class OrderableMcpToolsTest < ActiveSupport::TestCase
  test "folder gets order and move tools and a non-orderable type gets none" do
    refute defined?(::RecordingStudioMcp)
    RecordingStudio.set_capability_options(:orderable, on: "Folder", allows: ["Page"])

    assert_equal %w[order_page move_page], RecordingStudioOrderable::McpCopy.tool_names
    assert_equal ["Folder", "Folder"], tools_for("Folder").map { |tool| tool.fetch(:type) }
    assert_empty tools_for("Project")
    assert_empty tools_for("Page")
    assert_empty tools_for("Workspace")
    assert_nil RecordingStudioOrderable::McpCopy.register!

    RecordingStudio::Orderable::Api.register_capability_action!

    assert RecordingStudioApi.capability_action(:reorder)
    assert RecordingStudioApi.capability_action(:move_position)
  end

  private

  def tools_for(type)
    RecordingStudioOrderable::McpCopy.registrations.select { |tool| tool.fetch(:type) == type }
  end
end
