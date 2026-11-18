# frozen_string_literal: true

require "test_helper"

class OrderableOpenapiOverrideTest < ActiveSupport::TestCase
  PRESS_CENTER = "RecordingStudioPressCenters::PressCenter"

  teardown do
    RecordingStudio::Orderable::Api::OpenapiOverrides.reset!
  end

  test "capability action openapi_for returns the per-type title" do
    api = RecordingStudio::Orderable::Api
    api.override_openapi(
      type: PRESS_CENTER,
      action: :reorder,
      title: "Reorder press center",
      description: "Sets the order of children in this press center."
    )

    reorder = RecordingStudioApi.capability_action(:reorder)
    press = reorder.openapi_for(type: PRESS_CENTER, action: :reorder)
    folder = reorder.openapi_for(type: "Folder", action: :reorder)
    move = RecordingStudioApi.capability_action(:move_position).openapi_for(
      type: PRESS_CENTER,
      action: :move_position
    )

    assert_equal "Reorder press center", press.fetch(:title)
    assert_equal "Sets the order of children in this press center.", press.fetch(:description)
    assert_equal api::ACTIONS.fetch(:reorder).fetch(:summary), press.fetch(:summary)
    assert_equal api::ACTIONS.fetch(:reorder).fetch(:description), folder.fetch(:description)
    assert_equal api::ACTIONS.fetch(:move_position).fetch(:description), move.fetch(:description)
    assert_equal api::ACTIONS.fetch(:reorder).fetch(:summary), reorder.openapi.fetch(:summary)
    refute folder.key?(:title)
    refute move.key?(:title)
    refute reorder.openapi.key?(:title)
  end
end
