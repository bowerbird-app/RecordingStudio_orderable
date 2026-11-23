# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  PRESS_CENTER = "RecordingStudioPressCenters::PressCenter"
  GENERIC_NAMES = %w[capability_action reorder move_position list show create update delete].freeze
  FORBIDDEN = [
    "RecordingStudioOrderable", "Accessible", "permission", "Admin", ":edit", ":view", " role"
  ].freeze

  def teardown
    RecordingStudio::Orderable::Api::OpenapiOverrides.reset!
  end

  def test_register_is_a_no_op_when_mcp_is_absent
    refute defined?(::RecordingStudioMcp)

    assert_nil RecordingStudioOrderable::McpCopy.register!
    assert_nil RecordingStudio::Orderable::Api.register_capability_action!
  end

  def test_named_tools_are_reorder_children_and_move_child_position
    names = RecordingStudioOrderable::McpCopy.tool_names
    registrations = RecordingStudioOrderable::McpCopy.registrations
    by_name = registrations.to_h { |tool| [tool.fetch(:name), tool] }

    assert_equal %w[reorder_children move_child_position], names
    assert_equal names, by_name.keys
    GENERIC_NAMES.each { |name| refute_includes names, name }

    reorder = by_name.fetch("reorder_children")
    move = by_name.fetch("move_child_position")

    assert_equal :reorder, reorder.fetch(:action)
    assert_equal "Reorder children", reorder.fetch(:title)
    assert_equal :move_position, move.fetch(:action)
    assert_equal "Move child position", move.fetch(:title)
    [reorder, move].each do |tool|
      refute tool.key?(:type)
      refute tool.key?(:public_name)
      refute tool.key?(:operation)
      refute tool.key?(:endpoint)
      assert_includes tool.fetch(:description), "opt in to ordering"
      assert_includes tool.fetch(:description), "direct child"
      FORBIDDEN.each { |phrase| refute_includes tool.fetch(:description), phrase }
      refute_includes tool.fetch(:title), "RecordingStudio"
    end
  end

  def test_reorder_copy_states_partial_lists_and_rejected_ids
    description = description_for("reorder_children")

    assert_includes description, "Listed children move to the front"
    assert_includes description, "Omitted eligible children are appended"
    assert_includes description, "missing, foreign, already-trashed, or duplicate id is rejected"
    assert_includes description, "An empty list orders every eligible child"
    assert_includes description, "Children stay under this parent"
  end

  def test_move_copy_states_the_child_stays_and_bad_ids_are_rejected
    description = description_for("move_child_position")

    assert_includes description, "direct child that parent allows"
    assert_includes description, "counting from 0"
    assert_includes description, "puts the child last"
    assert_includes description, "missing, foreign, or already-trashed id is rejected"
    assert_includes description, "not an integer"
    assert_includes description, "The child stays under this parent"
  end

  def test_inputs_reuse_action_field_copy_and_name_the_parent
    api = RecordingStudio::Orderable::Api
    reorder = registration("reorder_children")
    move = registration("move_child_position")

    assert_equal "Public name of the parent type. That type must opt in to ordering.",
                 reorder.dig(:input, "type", :description)
    assert_equal "Recording id of the parent. Run this on the parent, not on a child.",
                 reorder.dig(:input, "id", :description)
    assert_equal api::ACTIONS.dig(:reorder, :fields, :ordered_recording_ids, :description),
                 reorder.dig(:input, "ordered_recording_ids", :description)
    assert_equal api::ACTIONS.dig(:move_position, :fields, :recording_id, :description),
                 move.dig(:input, "recording_id", :description)
    assert_equal api::ACTIONS.dig(:move_position, :fields, :to_index, :description),
                 move.dig(:input, "to_index", :description)
    assert_equal api::ACTIONS.dig(:reorder, :success), reorder.fetch(:output)
    assert_equal api::ACTIONS.dig(:move_position, :success), move.fetch(:output)
    assert_equal %w[type id ordered_recording_ids], reorder.fetch(:input).keys
    assert_equal %w[type id recording_id to_index], move.fetch(:input).keys
  end

  def test_per_type_openapi_titles_stay_off_the_named_tools
    api = RecordingStudio::Orderable::Api
    api.override_openapi(
      type: PRESS_CENTER,
      action: :reorder,
      title: "Reorder press center",
      description: "Sets the order of children in this press center."
    )
    api.override_openapi(
      type: PRESS_CENTER,
      action: :move_position,
      title: "Move press center position",
      description: "Moves one child to a new index in this press center."
    )

    assert_equal "Reorder press center", api.openapi_for(type: PRESS_CENTER, action: :reorder).fetch(:title)
    assert_equal "Move press center position",
                 api.openapi_for(type: PRESS_CENTER, action: :move_position).fetch(:title)
    assert_equal "Reorder children", registration("reorder_children").fetch(:title)
    assert_equal "Move child position", registration("move_child_position").fetch(:title)
    refute_includes registration("reorder_children").fetch(:description), "press center"
  end

  def test_gemspec_does_not_depend_on_mcp_and_registration_calls_the_copier
    root = File.expand_path("..", __dir__)
    gemspec = File.read(File.join(root, "recording_studio_orderable.gemspec"))
    api = File.read(File.join(root, "lib/recording_studio/orderable/api.rb"))
    registration = File.read(File.join(root, "lib/recording_studio/orderable/api/registration.rb"))
    copier = File.read(File.join(root, "lib/recording_studio_orderable/mcp_copy.rb"))

    refute_includes gemspec, "add_dependency \"recording_studio_mcp\""
    refute_includes api, "recording_studio_mcp"
    refute_includes registration, "register_tool"
    assert_includes api, "RecordingStudioOrderable::McpCopy.register!"
    assert_includes copier, "RecordingStudioMcp.register_tool"
    refute_includes copier, "register_type"
    refute_includes copier, "public_name"
  end

  private

  def registration(name)
    RecordingStudioOrderable::McpCopy.registrations.find { |tool| tool.fetch(:name) == name }
  end

  def description_for(name)
    registration(name).fetch(:description)
  end
end
