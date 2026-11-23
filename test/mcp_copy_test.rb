# frozen_string_literal: true

require "test_helper"
require "json"
require_relative "support/load_mcp_tool_name"

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

  def test_an_orderable_type_gets_order_and_move_tools_named_for_the_allowed_child
    tools = tools_for("List")

    assert_equal(%w[order_list_item move_list_item], tools.map { |tool| tool.fetch(:name) })
    assert_equal mcp_snapshot.fetch(:list_order), tools.first.fetch(:name)
    assert_equal mcp_snapshot.fetch(:list_move), tools.last.fetch(:name)
    assert_equal(%w[reorder move_position], tools.map { |tool| tool.fetch(:action) })
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
    refute mcp_snapshot.fetch(:order_enabled)
    assert_empty tools_for("Order")
    names = mcp_snapshot.fetch(:registrations).map { |tool| tool.fetch(:name) }
    refute_includes names, "order_order"
    refute_includes names, "reorder_children"
    refute_includes names, "move_child_position"
    refute_includes names, "capability_action"
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
    tool = tools_for("List").first

    assert_equal "Reorder press center", document.fetch(:title)
    assert_equal "Sets the order of children in this press center.", document.fetch(:description)
    assert_equal "Order list item", tool.fetch(:title)
    refute_equal document.fetch(:description), tool.fetch(:description)
    refute_includes tool.fetch(:description), "press center"
  ensure
    RecordingStudio::Orderable::Api::OpenapiOverrides.reset!
  end

  private

  def tools_for(type)
    registrations.select { |tool| tool.fetch(:type) == type }
  end

  def registrations
    mcp_snapshot.fetch(:registrations)
  end

  def mcp_snapshot
    @mcp_snapshot ||= in_mcp_process do
      enable("List", allows: ["ListItem"])
      enable("Shelf", allows: %w[Page Note])
      enable("Bin")
      enable("Alpha", allows: ["Widget"])
      enable("Beta", allows: ["Widget"])
      enable("Binder", allows: ["Statuses"])
      {
        registrations: RecordingStudioOrderable::McpCopy.registrations,
        list_order: RecordingStudioMcp.tool_name("ListItem", "order"),
        list_move: RecordingStudioMcp.tool_name("ListItem", "move"),
        order_enabled: RecordingStudio.capability_enabled?(:orderable, for: "Order")
      }
    end
  end

  def in_mcp_process(&block)
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      write_mcp_result(writer, &block)
    end
    writer.close
    raw = reader.read
    reader.close
    _pid, status = Process.wait2(pid)
    flunk("mcp process failed: #{status.inspect} #{raw}") unless status.success?

    kind, value = JSON.parse(raw)
    flunk(value) unless kind == "ok"
    normalize_snapshot(value)
  end

  def write_mcp_result(writer)
    LoadMcpToolName.load!
    writer.write(JSON.generate(["ok", json_ready(yield)]))
  rescue StandardError => e
    writer.write(JSON.generate(["err", "#{e.class}: #{e.message}"]))
  ensure
    writer.close
    Minitest::Runnable.runnables.clear
    flush_child_coverage
  end

  def flush_child_coverage
    return unless defined?(SimpleCov) && SimpleCov.running

    SimpleCov.pid = Process.pid
    SimpleCov.command_name "mcp copy #{Process.pid}"
    SimpleCov.print_error_status = false
    SimpleCov.minimum_coverage 0
    SimpleCov.result
  end

  def normalize_snapshot(value)
    {
      registrations: value.fetch("registrations").map { |tool| normalize_tool(tool) },
      list_order: value.fetch("list_order"),
      list_move: value.fetch("list_move"),
      order_enabled: value.fetch("order_enabled")
    }
  end

  def normalize_tool(tool)
    tool.to_h do |key, item|
      if key == "input"
        [:input, item.transform_values { |field| field.transform_keys(&:to_sym) }]
      else
        [key.to_sym, item]
      end
    end
  end

  def json_ready(value)
    case value
    when Hash then value.transform_keys(&:to_s).transform_values { |item| json_ready(item) }
    when Array then value.map { |item| json_ready(item) }
    when Symbol then value.to_s
    else value
    end
  end

  def enable(type, allows: nil)
    RecordingStudio.enable_capability(:orderable, on: type)
    return if allows.nil?

    RecordingStudio.set_capability_options(:orderable, on: type, allows: allows)
  end
end
