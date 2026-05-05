# frozen_string_literal: true

require "test_helper"

class RecordingOrderManagerTest < Minitest::Test
  class FakeFolder
    def self.recording_studio_order_group_definition(name = nil)
      groups = {
        "pages" => { group_key: "pages", allows: ["Page"] }
      }
      groups.fetch(name.to_s.presence || "pages")
    end
  end

  FakeRecording = Struct.new(:id, :recordable_type, :recordable, :created_at, :updated_at)
  FakeParentRecording = Struct.new(:id, :recordable, :child_recordings)
  FakeOwner = Struct.new(:id)

  def setup
    @page_one = FakeRecording.new("page-1", "Page", Struct.new(:title).new("Page 1"), Time.utc(2024, 1, 1),
                                  Time.utc(2024, 1, 1))
    @page_two = FakeRecording.new("page-2", "Page", Struct.new(:title).new("Page 2"), Time.utc(2024, 1, 2),
                                  Time.utc(2024, 1, 2))
    @page_three = FakeRecording.new("page-3", "Page", Struct.new(:title).new("Page 3"), Time.utc(2024, 1, 3),
                                    Time.utc(2024, 1, 3))
    @order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids).new("pages", nil, nil,
                                                                                        %w[page-2 missing-id page-1])
    @order_recording = FakeRecording.new("order-1", "RecordingStudio::RecordingOrder", @order, Time.utc(2024, 1, 4),
                                         Time.utc(2024, 1, 4))
    @owner = FakeOwner.new("user-1")
    @scoped_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids).new(
      "pages",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      ["page-3"]
    )
    @scoped_order_recording = FakeRecording.new("order-2", "RecordingStudio::RecordingOrder", @scoped_order,
                                                Time.utc(2024, 1, 5), Time.utc(2024, 1, 5))
    @parent_recording = FakeParentRecording.new("folder-1", FakeFolder.new,
                                                [@page_one, @page_two, @page_three, @order_recording])
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
      %w[page-3 missing-id page-3 page-1]
    )

    assert_equal %w[page-3 page-1], normalized_ids
  end

  def test_recording_order_for_can_resolve_owner_scoped_orders
    @parent_recording.child_recordings << @scoped_order_recording

    order = RecordingStudioOrderable::RecordingOrderManager.recording_order_for(
      @parent_recording,
      :pages,
      owner: @owner
    )

    assert_equal @scoped_order, order
  end

  def test_duplicate_matching_orders_raise_an_error
    duplicate_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids).new("pages", nil, nil, [])
    duplicate_recording = FakeRecording.new("order-3", "RecordingStudio::RecordingOrder", duplicate_order,
                                            Time.utc(2024, 1, 6), Time.utc(2024, 1, 6))
    @parent_recording.child_recordings << duplicate_recording

    error = assert_raises(RecordingStudioOrderable::RecordingOrderManager::DuplicateOrderError) do
      RecordingStudioOrderable::RecordingOrderManager.recording_order_for(@parent_recording, :pages)
    end

    assert_includes error.message, "Multiple RecordingOrder children exist"
  end

  def test_recording_order_recordings_filters_by_scope
    @parent_recording.child_recordings << @scoped_order_recording

    assert_equal [@scoped_order_recording],
                 RecordingStudioOrderable::RecordingOrderManager.recording_order_recordings(
                   @parent_recording,
                   :pages,
                   owner: @owner
                 )
  end

  def test_recording_orders_returns_recordables_for_scope
    @parent_recording.child_recordings << @scoped_order_recording

    assert_equal [@scoped_order],
                 RecordingStudioOrderable::RecordingOrderManager.recording_orders(
                   @parent_recording,
                   owner: @owner
                 )
  end

  def test_find_or_create_recording_order_returns_existing_order
    order = RecordingStudioOrderable::RecordingOrderManager.find_or_create_recording_order!(
      @parent_recording,
      :pages
    )

    assert_equal @order, order
  end

  def test_find_or_create_recording_order_builds_and_records_new_order
    parent_recording = FakeParentRecording.new("folder-2", FakeFolder.new, [@page_one, @page_two])
    recorded_arguments = nil

    parent_recording.define_singleton_method(:record) do |order_record, actor:, metadata:, parent_recording:|
      recorded_arguments = {
        order_record: order_record,
        actor: actor,
        metadata: metadata,
        parent_recording: parent_recording
      }
      Struct.new(:recordable).new(order_record)
    end

    with_temporary_recording_order_class do
      created_order = RecordingStudioOrderable::RecordingOrderManager.find_or_create_recording_order!(
        parent_recording,
        :pages,
        owner: @owner,
        actor: :actor,
        metadata: { source: "test" },
        name: "Scoped order",
        ordered_recording_ids: %w[page-2 missing-id]
      )

      assert_equal parent_recording.id, created_order.parent_recording_id
      assert_equal "pages", created_order.group_key
      assert_equal "Scoped order", created_order.name
      assert_equal "RecordingOrderManagerTest::FakeOwner", created_order.owner_type
      assert_equal "user-1", created_order.owner_id
      assert_equal ["page-2"], created_order.ordered_recording_ids
      assert_same parent_recording, created_order.parent_recording_for_validation
      assert_nil created_order.recording_id_for_validation
      assert_equal({ source: "test" }, recorded_arguments[:metadata])
      assert_equal :actor, recorded_arguments[:actor]
      assert_same parent_recording, recorded_arguments[:parent_recording]
      assert_same created_order, recorded_arguments[:order_record]
    end
  end

  def test_resolve_group_definition_requires_orderable_parent
    parent_recording = FakeParentRecording.new("folder-3", Object.new, [])

    error = assert_raises(RecordingStudioOrderable::RecordingOrderManager::ConfigurationError) do
      RecordingStudioOrderable::RecordingOrderManager.resolve_group_definition!(parent_recording, :pages)
    end

    assert_includes error.message, "does not define any recording_studio_order_group entries"
  end

  private

  def with_temporary_recording_order_class
    had_constant = RecordingStudio.const_defined?(:RecordingOrder, false)
    original_constant = RecordingStudio.const_get(:RecordingOrder) if had_constant
    temporary_class = Class.new do
      attr_accessor :parent_recording_id,
                    :group_key,
                    :name,
                    :owner_type,
                    :owner_id,
                    :ordered_recording_ids,
                    :parent_recording_for_validation,
                    :recording_id_for_validation

      def initialize(attributes = {})
        attributes.each do |key, value|
          public_send("#{key}=", value)
        end
      end
    end

    RecordingStudio.send(:remove_const, :RecordingOrder) if had_constant
    RecordingStudio.const_set(:RecordingOrder, temporary_class)
    yield
  ensure
    RecordingStudio.send(:remove_const, :RecordingOrder) if RecordingStudio.const_defined?(:RecordingOrder, false)
    RecordingStudio.const_set(:RecordingOrder, original_constant) if had_constant
  end
end
