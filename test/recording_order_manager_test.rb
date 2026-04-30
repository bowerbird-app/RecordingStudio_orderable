# frozen_string_literal: true

require "test_helper"

class RecordingOrderManagerTest < Minitest::Test
  class FakeFolder
    def self.recording_studio_order_group_definition(name = nil)
      groups = {
        "pages" => {name: "pages", allows: ["Page"]}
      }
      groups.fetch(name.to_s.presence || "pages")
    end
  end

  FakeRecording = Struct.new(:id, :recordable_type, :recordable, :created_at, :updated_at)
  FakeParentRecording = Struct.new(:id, :recordable, :child_recordings)

  def setup
    @page_one = FakeRecording.new("page-1", "Page", Struct.new(:title).new("Page 1"), Time.utc(2024, 1, 1), Time.utc(2024, 1, 1))
    @page_two = FakeRecording.new("page-2", "Page", Struct.new(:title).new("Page 2"), Time.utc(2024, 1, 2), Time.utc(2024, 1, 2))
    @page_three = FakeRecording.new("page-3", "Page", Struct.new(:title).new("Page 3"), Time.utc(2024, 1, 3), Time.utc(2024, 1, 3))
    @order = Struct.new(:order_group, :ordered_recording_ids).new("pages", ["page-2", "missing-id", "page-1"])
    @order_recording = FakeRecording.new("order-1", "RecordingStudio::RecordingOrder", @order, Time.utc(2024, 1, 4), Time.utc(2024, 1, 4))
    @parent_recording = FakeParentRecording.new("folder-1", FakeFolder.new, [@page_one, @page_two, @page_three, @order_recording])
  end

  def test_ordered_children_ignore_stale_ids_and_append_unordered_eligible_children
    ordered_children = RecordingStudioOrderable::RecordingOrderManager.ordered_children_for(@parent_recording, :pages)

    assert_equal [@page_two, @page_one, @page_three], ordered_children
  end

  def test_eligible_children_are_sorted_by_created_at_then_id
    eligible_children = RecordingStudioOrderable::RecordingOrderManager.eligible_children_for(@parent_recording, :pages)

    assert_equal [@page_one, @page_two, @page_three], eligible_children
  end

  def test_normalize_requested_ids_keeps_only_eligible_unique_ids
    normalized_ids = RecordingStudioOrderable::RecordingOrderManager.normalize_requested_ids(
      @parent_recording,
      :pages,
      ["page-3", "missing-id", "page-3", "page-1"]
    )

    assert_equal %w[page-3 page-1], normalized_ids
  end
end
