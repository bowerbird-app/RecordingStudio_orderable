# frozen_string_literal: true

require "test_helper"

class RecordingOrderTest < Minitest::Test
  VALID_PARENT_ID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  VALID_ROOT_ID = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  VALID_CHILD_ID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
  OTHER_CHILD_ID = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"

  FakeParentRecording = Struct.new(:id, :root_recording_id)
  FakeChildRecording = Struct.new(:id, :parent_recording_id, :root_recording_id, :recordable_type)

  def setup
    @parent_recording = FakeParentRecording.new(VALID_PARENT_ID, VALID_ROOT_ID)
    @child_recording = FakeChildRecording.new(VALID_CHILD_ID, VALID_PARENT_ID, VALID_ROOT_ID, "Page")
  end

  def test_valid_when_ids_reference_allowed_direct_children
    order = build_order([VALID_CHILD_ID])

    stub_dependencies(matchers: [], children: [@child_recording]) do
      assert order.valid?, order.errors.full_messages.join(", ")
    end
  end

  def test_invalid_when_id_points_to_child_under_another_parent
    other_child = FakeChildRecording.new(OTHER_CHILD_ID, "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee", VALID_ROOT_ID, "Page")
    order = build_order([OTHER_CHILD_ID])

    stub_dependencies(matchers: [], children: [other_child]) do
      refute order.valid?
      assert_includes order.errors[:ordered_recording_ids], "must only include direct children of the same parent recording"
    end
  end

  def test_invalid_when_scope_already_exists
    order = build_order([])
    existing = Struct.new(:id).new("existing-recording-id")

    stub_dependencies(matchers: [existing], children: []) do
      refute order.valid?
      assert_includes order.errors[:base], "an order already exists for this parent, group, and owner scope"
    end
  end

  private

  def build_order(ids)
    RecordingStudio::RecordingOrder.new(
      parent_recording_id: VALID_PARENT_ID,
      group_key: "pages",
      ordered_recording_ids: ids
    ).tap do |order|
      order.parent_recording_for_validation = @parent_recording
    end
  end

  def stub_dependencies(matchers:, children:)
    definition = { group_key: "pages", allows: ["Page"] }
    where_result = children.index_by { |recording| recording.id.to_s }.values

    RecordingStudioOrderable::RecordingOrderManager.stub(:resolve_group_definition!, definition) do
      RecordingStudioOrderable::RecordingOrderManager.stub(:matching_order_recordings, matchers) do
        RecordingStudio::Recording.stub(:where, where_result) do
          yield
        end
      end
    end
  end
end
