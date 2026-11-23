# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  PRESS_CENTER = "RecordingStudioPressCenters::PressCenter"
  FORBIDDEN = [
    "RecordingStudioOrderable", "Accessible", "permission", "Admin", ":edit", ":view", " role"
  ].freeze

  def test_register_is_a_no_op_when_mcp_is_absent
    refute defined?(::RecordingStudioMcp)
    refute Object.const_defined?(:RecordingStudioApi, false)
    assert_empty RecordingStudioOrderable::McpCopy.tool_names
    assert_empty RecordingStudioOrderable::McpCopy.registrations
    assert_nil RecordingStudioOrderable::McpCopy.register!
  end

  def test_reorder_and_move_copy_state_the_write_rules
    copy = RecordingStudioOrderable::McpCopy::Copy

    assert_includes copy::REORDER, "Listed children move to the front"
    assert_includes copy::REORDER, "Omitted eligible children are appended"
    assert_includes copy::REORDER, "missing, foreign, already-trashed, or duplicate id is rejected"
    assert_includes copy::REORDER, "Children stay under this parent"
    assert_includes copy::MOVE, "direct child this parent allows"
    assert_includes copy::MOVE, "counting from 0"
    assert_includes copy::MOVE, "The child stays under this parent"
    assert_equal "The children are in the new order.", copy::OUTPUTS.fetch(:reorder)
    assert_equal "The child is at the new index.", copy::OUTPUTS.fetch(:move_position)
    assert_equal "Recording id of this parent.", copy::ID_INPUT.fetch(:description)
    assert_includes copy::FIELD_COPY.dig(:reorder, "ordered_recording_ids"), "Listed children move to the front"
    assert_includes copy::FIELD_COPY.dig(:move_position, "recording_id"), "direct child to move"
    assert_includes copy::FIELD_COPY.dig(:move_position, "to_index"), "counting from 0"
    FORBIDDEN.each do |phrase|
      refute_includes copy::REORDER, phrase
      refute_includes copy::MOVE, phrase
    end
  end

  def test_api_copy_is_for_http_clients_and_differs_from_mcp_copy
    api = RecordingStudio::Orderable::Api::ACTIONS
    copy = RecordingStudioOrderable::McpCopy::Copy
    reorder = api.fetch(:reorder)
    move = api.fetch(:move_position)

    assert_equal "Reorder the direct children of this recording.", reorder.fetch(:summary)
    assert_equal "Move one direct child to a new index.", move.fetch(:summary)
    assert_includes reorder.fetch(:description), "POST"
    assert_includes reorder.fetch(:description), "appended"
    assert_includes reorder.fetch(:description), "InvalidChild"
    assert_includes move.fetch(:description), "InvalidChild"
    refute_includes reorder.fetch(:description), "Run this"
    refute_includes move.fetch(:description), "Run this"
    refute_equal reorder.fetch(:description), copy::REORDER
    refute_equal move.fetch(:description), copy::MOVE
    refute_equal reorder.fetch(:success), copy::OUTPUTS.fetch(:reorder)
    refute_equal move.fetch(:success), copy::OUTPUTS.fetch(:move_position)
    refute_equal reorder.dig(:fields, :ordered_recording_ids, :description),
                 copy::FIELD_COPY.dig(:reorder, "ordered_recording_ids")
    refute_equal move.dig(:fields, :recording_id, :description),
                 copy::FIELD_COPY.dig(:move_position, "recording_id")
    refute_includes copy::REORDER, "POST"
    refute_includes copy::REORDER, "InvalidChild"
    refute_includes copy::MOVE, "InvalidChild"
  end

  def test_openapi_override_does_not_change_mcp_copy
    api = RecordingStudio::Orderable::Api
    before = RecordingStudioOrderable::McpCopy::Copy::REORDER.dup
    api.override_openapi(
      type: PRESS_CENTER,
      action: :reorder,
      title: "Reorder press center",
      description: "Sets the order of children in this press center."
    )
    document = api.openapi_for(type: PRESS_CENTER, action: :reorder)

    assert_equal "Reorder press center", document.fetch(:title)
    assert_equal "Sets the order of children in this press center.", document.fetch(:description)
    assert_equal before, RecordingStudioOrderable::McpCopy::Copy::REORDER
    refute_includes RecordingStudioOrderable::McpCopy::Copy::REORDER, "press center"
  ensure
    RecordingStudio::Orderable::Api::OpenapiOverrides.reset!
  end
end
