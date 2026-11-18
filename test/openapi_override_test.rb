# frozen_string_literal: true

require "test_helper"

class OpenapiOverrideTest < Minitest::Test
  PRESS_CENTER = "RecordingStudioPressCenters::PressCenter"

  def teardown
    RecordingStudio::Orderable::Api::OpenapiOverrides.reset!
  end

  def test_override_applies_to_that_type_and_action_only
    api = RecordingStudio::Orderable::Api
    override_press_center

    reorder = api.openapi_for(type: PRESS_CENTER, action: :reorder)
    move = api.openapi_for(type: PRESS_CENTER, action: :move_position)
    folder = api.openapi_for(type: "Folder", action: :reorder)
    missing = api.openapi_for(type: "Missing", action: :reorder)
    generic = api.openapi_for(action: :reorder)
    from_string = api.openapi_for(type: PRESS_CENTER, action: "reorder")

    assert_equal "Reorder press center", reorder.fetch(:title)
    assert_equal "Sets the order of children in this press center.", reorder.fetch(:description)
    assert_equal api::ACTIONS.fetch(:reorder).fetch(:summary), reorder.fetch(:summary)
    assert_equal "Move press center position", move.fetch(:title)
    assert_equal "Moves one child to a new index in this press center.", move.fetch(:description)
    assert_equal api::ACTIONS.fetch(:move_position).fetch(:summary), move.fetch(:summary)
    assert_equal api::ACTIONS.fetch(:reorder).fetch(:description), folder.fetch(:description)
    assert_equal api::ACTIONS.fetch(:reorder).fetch(:description), missing.fetch(:description)
    assert_equal api::ACTIONS.fetch(:reorder).fetch(:description), generic.fetch(:description)
    assert_equal "Reorder press center", from_string.fetch(:title)
    refute folder.key?(:title)
    refute missing.key?(:title)
    refute generic.key?(:title)

    reorder[:title] = "changed"
    again = api.openapi_for(type: PRESS_CENTER, action: :reorder)
    assert_equal "Reorder press center", again.fetch(:title)
  end

  def test_override_rejects_unknown_action_and_blank_arguments
    api = RecordingStudio::Orderable::Api

    unknown = assert_raises(ArgumentError) do
      api.override_openapi(type: "Folder", action: :move, title: "Move", description: "Moves it.")
    end
    blank_type = assert_raises(ArgumentError) do
      api.override_openapi(type: "  ", action: :reorder, title: "Reorder", description: "Reorders.")
    end
    missing_title = assert_raises(ArgumentError) do
      api.override_openapi(type: "Folder", action: :reorder, title: nil, description: "Reorders.")
    end
    missing_description = assert_raises(ArgumentError) do
      api.override_openapi(type: "Folder", action: :reorder, title: "Reorder", description: nil)
    end

    assert_equal "Unknown Orderable action :move", unknown.message
    assert_equal "type is required", blank_type.message
    assert_equal "title is required", missing_title.message
    assert_equal "description is required", missing_description.message
    refute api.openapi_for(type: "Folder", action: :reorder).key?(:title)
  end

  def test_openapi_for_rejects_an_unknown_action
    assert_raises(KeyError) do
      RecordingStudio::Orderable::Api.openapi_for(type: "Folder", action: :move)
    end
  end

  private

  def override_press_center
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
  end
end
