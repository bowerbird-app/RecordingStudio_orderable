# frozen_string_literal: true

require "test_helper"

class OrderableMcpToolsTest < ActiveSupport::TestCase
  PRESS_CENTER = "RecordingStudioPressCenters::PressCenter"

  setup do
    @orderable_types_before = RecordingStudio.configuration.enabled_recordable_types_for(:orderable)
    @orderable_options_before = @orderable_types_before.to_h do |type|
      [ type, RecordingStudio.capability_options(:orderable, for: type) ]
    end
    @mcp_tools_before = RecordingStudioMcp.configuration.tools.dup
  end

  teardown do
    restore_orderable!
    restore_mcp_tools!
    RecordingStudio::Orderable::Api::OpenapiOverrides.reset!
  end

  test "folder that allows page registers order_page and move_page" do
    RecordingStudio.set_capability_options(:orderable, on: "Folder", allows: [ "Page" ])
    register!

    assert_equal %w[order_page move_page], names_for("Folder")
    assert_equal RecordingStudioMcp.tool_name("Page", "order"), names_for("Folder").first
    assert_equal RecordingStudioMcp.tool_name("Page", "move"), names_for("Folder").last
    assert_tool "order_page", type: "Folder", action: :reorder, title: "Order page"
    assert_tool "move_page", type: "Folder", action: :move_position, title: "Move page"
  end

  test "list that allows list item registers order_list_item and move_list_item" do
    enable_orderable("List", allows: [ "ListItem" ])
    register!

    assert_equal %w[order_list_item move_list_item], names_for("List")
    assert_equal RecordingStudioMcp.tool_name("ListItem", "order"), names_for("List").first
    assert_equal RecordingStudioMcp.tool_name("ListItem", "move"), names_for("List").last
    order = RecordingStudioMcp.configuration.tool("order_list_item")
    assert_includes order.description, "Listed children move to the front"
    assert_includes order.description, "missing, foreign, already-trashed, or duplicate id is rejected"
    assert_equal "The children are in the new order.", order.output
    assert_equal %w[id ordered_recording_ids], order.input.keys
    move = RecordingStudioMcp.configuration.tool("move_list_item")
    assert_includes move.description, "direct child this parent allows"
    assert_equal "The child is at the new index.", move.output
    assert_equal %w[id recording_id to_index], move.input.keys
  end

  test "several or omitted allows use the parent name" do
    enable_orderable("Shelf", allows: %w[Page Note])
    enable_orderable("Bin")
    register!

    assert_equal %w[order_shelf move_shelf], names_for("Shelf")
    assert_equal %w[order_bin move_bin], names_for("Bin")
    assert_equal RecordingStudioMcp.tool_name("Shelf", "order"), names_for("Shelf").first
    assert_equal RecordingStudioMcp.tool_name("Bin", "move"), names_for("Bin").last
  end

  test "a shared child noun is prefixed with the parent" do
    enable_orderable("Alpha", allows: [ "Widget" ])
    enable_orderable("Beta", allows: [ "Widget" ])
    register!

    assert_equal %w[order_alpha_widget move_alpha_widget], names_for("Alpha")
    assert_equal %w[order_betum_widget move_betum_widget], names_for("Beta")
    assert_equal prefixed_names("Alpha", "Widget"), names_for("Alpha")
    assert_equal prefixed_names("Beta", "Widget"), names_for("Beta")
  end

  test "a plural allowed type is singularized" do
    enable_orderable("Binder", allows: [ "Statuses" ])
    register!

    assert_equal %w[order_status move_status], names_for("Binder")
    assert_equal RecordingStudioMcp.tool_name("Statuses", "order"), names_for("Binder").first
    assert_equal RecordingStudioMcp.tool_name("Statuses", "move"), names_for("Binder").last
  end

  test "a type without orderable registers no tool" do
    register!

    assert_empty names_for("Project")
    assert_empty names_for("Page")
    assert_empty names_for("Workspace")
    refute RecordingStudioMcp.configuration.tool("order_project")
    refute RecordingStudioMcp.configuration.tool("move_project")
    refute RecordingStudioMcp.configuration.tool("order_workspace")
    refute RecordingStudioMcp.configuration.tool("move_workspace")
  end

  test "an openapi title stays off the named tool" do
    RecordingStudio::Orderable::Api.override_openapi(
      type: PRESS_CENTER,
      action: :reorder,
      title: "Reorder press center",
      description: "Sets the order of children in this press center."
    )
    register!
    tool = RecordingStudioMcp.configuration.tool("order_page")

    assert_equal "Order page", tool.title
    refute_includes tool.description, "press center"
    refute_equal "Reorder press center", tool.title
  end

  private

  def register!
    drop_orderable_tools!
    RecordingStudioOrderable::McpCopy.register!
  end

  def enable_orderable(type, allows: nil)
    RecordingStudio.enable_capability(:orderable, on: type)
    return if allows.nil?

    RecordingStudio.set_capability_options(:orderable, on: type, allows: allows)
  end

  def names_for(type)
    RecordingStudioMcp.configuration.tools.each_value
      .select { |tool| tool.type == type }
      .map(&:name)
      .sort_by { |name| name.start_with?("move_") ? 1 : 0 }
  end

  def prefixed_names(parent, child)
    parent_token = RecordingStudioMcp.tool_name(parent, "order").delete_prefix("order_")
    child_token = RecordingStudioMcp.tool_name(child, "order").delete_prefix("order_")
    %w[order move].map { |verb| "#{verb}_#{parent_token}_#{child_token}" }
  end

  def assert_tool(name, type:, action:, title:)
    tool = RecordingStudioMcp.configuration.tool(name)
    assert tool, "expected registered tool #{name}"
    assert_equal type, tool.type
    assert_equal title, tool.title
    assert tool.target.action?
    assert_equal action, tool.target.value
  end

  def drop_orderable_tools!
    RecordingStudioMcp.configuration.tools.delete_if do |_name, tool|
      tool.target.action? && %i[reorder move_position].include?(tool.target.value)
    end
  end

  def restore_orderable!
    current = RecordingStudio.configuration.enabled_recordable_types_for(:orderable)
    (current - @orderable_types_before).each { |type| remove_orderable!(type) }
    @orderable_options_before.each do |type, saved|
      if saved.nil?
        remove_orderable_options!(type)
      else
        RecordingStudio.set_capability_options(:orderable, on: type, **saved.to_h.symbolize_keys)
      end
    end
  end

  def remove_orderable!(type)
    RecordingStudio.synchronize_capabilities do
      capabilities = RecordingStudio.configuration.instance_variable_get(:@capabilities)
      options = RecordingStudio.configuration.instance_variable_get(:@capability_options)
      capabilities[type]&.delete(:orderable)
      capabilities.delete(type) if capabilities[type]&.empty?
      options.delete([ :orderable, type ])
    end
  end

  def remove_orderable_options!(type)
    RecordingStudio.synchronize_capabilities do
      RecordingStudio.configuration.instance_variable_get(:@capability_options).delete([ :orderable, type ])
    end
  end

  def restore_mcp_tools!
    tools = RecordingStudioMcp.configuration.tools
    tools.clear
    @mcp_tools_before.each_value do |registration|
      RecordingStudioMcp.configuration.add_tool(registration, override: true)
    end
  end
end
