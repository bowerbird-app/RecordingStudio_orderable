# frozen_string_literal: true

require "test_helper"

class OrderableMcpToolsTest < ActiveSupport::TestCase
  test "named tools stay registered as a no-op when MCP is absent" do
    refute defined?(::RecordingStudioMcp)

    assert_equal %w[reorder_children move_child_position], RecordingStudioOrderable::McpCopy.tool_names
    assert_nil RecordingStudioOrderable::McpCopy.register!

    RecordingStudio::Orderable::Api.register_capability_action!

    assert RecordingStudioApi.capability_action(:reorder)
    assert RecordingStudioApi.capability_action(:move_position)
    assert_nil RecordingStudioOrderable::McpCopy.register!
  end
end
