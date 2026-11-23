# frozen_string_literal: true

require "test_helper"
require_relative "support/load_mcp_tool_name"

class McpCopyTest < Minitest::Test
  ABSENT = {
    loaded: defined?(::RecordingStudioMcp),
    names: RecordingStudioOrderable::McpCopy.tool_names.freeze,
    registrations: RecordingStudioOrderable::McpCopy.registrations.freeze,
    registered: RecordingStudioOrderable::McpCopy.register!
  }.freeze
  PRESS_CENTER = "RecordingStudioPressCenters::PressCenter"
  FORBIDDEN = [
    "RecordingStudioOrderable", "Accessible", "permission", "Admin", ":edit", ":view", " role"
  ].freeze

  def setup
    LoadMcpToolName.load!
    enable("List", allows: ["ListItem"])
    enable("Shelf", allows: %w[Page Note])
    enable("Bin")
    enable("Alpha", allows: ["Widget"])
    enable("Beta", allows: ["Widget"])
    enable("Binder", allows: ["Statuses"])
  end

  def teardown
    RecordingStudio::Orderable::Api::OpenapiOverrides.reset!
  end

  def test_register_is_a_no_op_when_mcp_is_absent
    assert_nil ABSENT.fetch(:loaded)
    assert_empty ABSENT.fetch(:names)
    assert_empty ABSENT.fetch(:registrations)
    assert_nil ABSENT.fetch(:registered)
  end

  def test_an_orderable_type_gets_order_and_move_tools_named_for_the_allowed_child
    tools = tools_for("List")

    assert_equal(%w[order_list_item move_list_item], tools.map { |tool| tool.fetch(:name) })
    assert_equal RecordingStudioMcp.tool_name("ListItem", "order"), tools.first.fetch(:name)
    assert_equal RecordingStudioMcp.tool_name("ListItem", "move"), tools.last.fetch(:name)
    assert_equal(%i[reorder move_position], tools.map { |tool| tool.fetch(:action) })
    assert_equal(%w[List List], tools.map { |tool| tool.fetch(:type) })
    assert_equal(["Order list item", "Move list item"], tools.map { |tool| tool.fetch(:title) })
    tools.each do |tool|
      refute tool.key?(:public_name)
      refute tool.key?(:operation)
      refute tool.key?(:endpoint)
      refute tool.fetch(:input).key?("type")
      refute_includes tool.fetch(:name), "::"
      FORBIDDEN.each { |phrase| refute_includes tool.fetch(:description), phrase }
    end
  end

  def test_a_type_without_orderable_gets_no_tool
    refute RecordingStudio.capability_enabled?(:orderable, for: "Order")
    assert_empty tools_for("Order")
    refute_includes RecordingStudioOrderable::McpCopy.tool_names, "order_order"
    refute_includes RecordingStudioOrderable::McpCopy.tool_names, "reorder_children"
    refute_includes RecordingStudioOrderable::McpCopy.tool_names, "move_child_position"
    refute_includes RecordingStudioOrderable::McpCopy.tool_names, "capability_action"
  end

  def test_a_plural_public_name_is_singularized
    names = tools_for("Binder").map { |tool| tool.fetch(:name) }

    assert_equal %w[order_status move_status], names
  end

  def test_several_or_omitted_allows_use_the_parent_public_name
    assert_equal(%w[order_shelf move_shelf], tools_for("Shelf").map { |tool| tool.fetch(:name) })
    assert_equal(%w[order_bin move_bin], tools_for("Bin").map { |tool| tool.fetch(:name) })
  end

  def test_shared_child_nouns_gain_the_parent_public_name
    assert_equal(%w[order_alpha_widget move_alpha_widget], tools_for("Alpha").map { |tool| tool.fetch(:name) })
    assert_equal(%w[order_betum_widget move_betum_widget], tools_for("Beta").map { |tool| tool.fetch(:name) })
  end

  def test_reorder_and_move_copy_state_the_write_rules
    reorder = tools_for("List").first
    move = tools_for("List").last

    assert_includes reorder.fetch(:description), "Listed children move to the front"
    assert_includes reorder.fetch(:description), "Omitted eligible children are appended"
    assert_includes reorder.fetch(:description), "missing, foreign, already-trashed, or duplicate id is rejected"
    assert_includes reorder.fetch(:description), "Children stay under this parent"
    assert_includes move.fetch(:description), "direct child this parent allows"
    assert_includes move.fetch(:description), "counting from 0"
    assert_includes move.fetch(:description), "The child stays under this parent"
    assert_equal %w[id ordered_recording_ids], reorder.fetch(:input).keys
    assert_equal %w[id recording_id to_index], move.fetch(:input).keys
    assert_equal "The children are in the new order.", reorder.fetch(:output)
    assert_equal "The child is at the new index.", move.fetch(:output)
  end

  def test_api_copy_is_for_http_clients_and_differs_from_mcp_copy
    api = RecordingStudio::Orderable::Api::ACTIONS
    reorder = tools_for("List").first
    move = tools_for("List").last
    reorder_api = api.fetch(:reorder)
    move_api = api.fetch(:move_position)

    assert_equal "Reorder the direct children of this recording.", reorder_api.fetch(:summary)
    assert_equal "Move one direct child to a new index.", move_api.fetch(:summary)
    assert_includes reorder_api.fetch(:description), "POST"
    assert_includes reorder_api.fetch(:description), "appended"
    assert_includes reorder_api.fetch(:description), "InvalidChild"
    assert_includes move_api.fetch(:description), "InvalidChild"
    refute_includes reorder_api.fetch(:description), "Run this"
    refute_includes move_api.fetch(:description), "Run this"
    refute_equal reorder_api.fetch(:description), reorder.fetch(:description)
    refute_equal move_api.fetch(:description), move.fetch(:description)
    refute_equal reorder_api.fetch(:success), reorder.fetch(:output)
    refute_equal move_api.fetch(:success), move.fetch(:output)
    refute_equal reorder_api.dig(:fields, :ordered_recording_ids, :description),
                 reorder.dig(:input, "ordered_recording_ids", :description)
    refute_equal move_api.dig(:fields, :recording_id, :description),
                 move.dig(:input, "recording_id", :description)
  end

  def test_per_type_openapi_titles_stay_off_the_named_tools
    api = RecordingStudio::Orderable::Api
    api.override_openapi(
      type: PRESS_CENTER,
      action: :reorder,
      title: "Reorder press center",
      description: "Sets the order of children in this press center."
    )

    document = api.openapi_for(type: PRESS_CENTER, action: :reorder)

    assert_equal "Reorder press center", document.fetch(:title)
    assert_equal "Sets the order of children in this press center.", document.fetch(:description)
    assert_equal "Order list item", tools_for("List").first.fetch(:title)
    refute_equal document.fetch(:description), tools_for("List").first.fetch(:description)
    refute_includes tools_for("List").first.fetch(:description), "press center"
  end

  private

  def enable(type, allows: nil)
    RecordingStudio.enable_capability(:orderable, on: type)
    return if allows.nil?

    RecordingStudio.set_capability_options(:orderable, on: type, allows: allows)
  end

  def tools_for(type)
    RecordingStudioOrderable::McpCopy.registrations.select { |tool| tool.fetch(:type) == type }
  end
end
