# frozen_string_literal: true

require "test_helper"

class RecordingOrderManagerTest < Minitest::Test
  class FakeFolder
    def self.recording_studio_order_group_definitions
      {
        "pages" => { group_key: "pages", allows: ["Page"] }
      }
    end

    def self.recording_studio_order_group_definition(name = nil)
      groups = recording_studio_order_group_definitions
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
    @order_recording = FakeRecording.new(
      "order-1",
      "RecordingStudio::RecordingStudioOrder",
      @order,
      Time.utc(2024, 1, 4),
      Time.utc(2024, 1, 4)
    )
    @owner = FakeOwner.new("user-1")
    @scoped_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids).new(
      "pages",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      ["page-3"]
    )
    @scoped_order_recording = FakeRecording.new("order-2", "RecordingStudio::RecordingStudioOrder", @scoped_order,
                                                Time.utc(2024, 1, 5), Time.utc(2024, 1, 5))
    @parent_recording = FakeParentRecording.new("folder-1", FakeFolder.new,
                                                [@page_one, @page_two, @page_three, @order_recording])
  end

  def test_ordered_children_ignore_stale_ids_and_append_unordered_eligible_children
    ordered_children = RecordingStudioOrderable::RecordingOrderManager.ordered_items_for(@parent_recording, :pages)

    assert_equal [@page_two, @page_one, @page_three], ordered_children
  end

  def test_ordered_children_append_newly_eligible_children_after_explicit_order
    page_four = FakeRecording.new("page-4", "Page", Struct.new(:title).new("Page 4"), Time.utc(2024, 1, 4),
                                  Time.utc(2024, 1, 4))
    @order.ordered_recording_ids = %w[page-2 page-1 page-3]
    @parent_recording.child_recordings << page_four

    ordered_children = RecordingStudioOrderable::RecordingOrderManager.ordered_items_for(@parent_recording, :pages)

    assert_equal [@page_two, @page_one, @page_three, page_four], ordered_children
    assert_equal %w[page-2 page-1 page-3], @order.ordered_recording_ids
  end

  def test_eligible_children_are_sorted_by_created_at_then_id
    eligible_children = RecordingStudioOrderable::RecordingOrderManager.eligible_items_for(@parent_recording, :pages)

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

    order = RecordingStudioOrderable::RecordingOrderManager.default_recording_order(
      @parent_recording,
      :pages,
      owner: @owner
    )

    assert_equal @scoped_order, order
  end

  def test_recording_order_for_prefers_the_unnamed_default_order_when_named_orders_exist
    named_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids, :name).new(
      "pages",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      ["page-1"],
      "Johnny's list"
    )
    named_order_recording = FakeRecording.new("order-3", "RecordingStudio::RecordingStudioOrder", named_order,
                                              Time.utc(2024, 1, 6), Time.utc(2024, 1, 6))
    @parent_recording.child_recordings << @scoped_order_recording
    @parent_recording.child_recordings << named_order_recording

    order = RecordingStudioOrderable::RecordingOrderManager.default_recording_order(
      @parent_recording,
      :pages,
      owner: @owner
    )

    assert_equal @scoped_order, order
  end

  def test_find_recording_order_by_id_returns_matching_order
    order = RecordingStudioOrderable::RecordingOrderManager.find_recording_order_by_id(
      @parent_recording,
      "order-1",
      group_key: :pages,
      owner: nil
    )

    assert_equal @order, order
  end

  def test_find_recording_order_by_id_raises_when_id_is_missing
    error = assert_raises(ActiveRecord::RecordNotFound) do
      RecordingStudioOrderable::RecordingOrderManager.find_recording_order_by_id(
        @parent_recording,
        "missing-order-id"
      )
    end

    assert_includes error.message, "RecordingStudioOrder not found"
  end

  def test_find_recording_order_by_id_raises_when_owner_guardrail_does_not_match
    @parent_recording.child_recordings << @scoped_order_recording
    different_owner = FakeOwner.new("user-2")

    assert_raises(ActiveRecord::RecordNotFound) do
      RecordingStudioOrderable::RecordingOrderManager.find_recording_order_by_id(
        @parent_recording,
        "order-2",
        owner: different_owner
      )
    end
  end

  def test_find_recording_order_by_id_without_owner_guardrail_can_find_scoped_order
    @parent_recording.child_recordings << @scoped_order_recording

    order = RecordingStudioOrderable::RecordingOrderManager.find_recording_order_by_id(
      @parent_recording,
      "order-2"
    )

    assert_equal @scoped_order, order
  end

  def test_recording_orders_can_be_filtered_to_named_orders_for_scope
    second_named_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids, :name).new(
      "pages",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      %w[page-1 page-2],
      "Another list"
    )
    named_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids, :name).new(
      "pages",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      ["page-3"],
      "Johnny's list"
    )
    @parent_recording.child_recordings << @scoped_order_recording
    @parent_recording.child_recordings << FakeRecording.new(
      "order-3",
      "RecordingStudio::RecordingStudioOrder",
      named_order,
      Time.utc(2024, 1, 6),
      Time.utc(2024, 1, 6)
    )
    @parent_recording.child_recordings << FakeRecording.new(
      "order-4",
      "RecordingStudio::RecordingStudioOrder",
      second_named_order,
      Time.utc(2024, 1, 7),
      Time.utc(2024, 1, 7)
    )

    orders = RecordingStudioOrderable::RecordingOrderManager.recording_orders(
      @parent_recording,
      owner: @owner,
      group: :pages
    ).reject do |order|
      order_name = order.respond_to?(:name) ? order.name : nil
      [nil, ""].include?(order_name)
    end

    assert_equal [named_order, second_named_order], orders
  end

  def test_recording_order_recordings_named_only_returns_only_owned_named_order_recordings
    named_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids, :name).new(
      "pages",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      ["page-3"],
      "Johnny's list"
    )
    named_order_recording = FakeRecording.new("order-3", "RecordingStudio::RecordingStudioOrder", named_order,
                                              Time.utc(2024, 1, 6), Time.utc(2024, 1, 6))
    @parent_recording.child_recordings << named_order_recording

    match = RecordingStudioOrderable::RecordingOrderManager.recording_order_recordings(
      @parent_recording,
      :pages,
      owner: @owner,
      named_only: true
    ).find { |recording| recording.id == "order-3" }

    assert_equal named_order_recording, match
  end

  def test_recording_orders_named_only_matches_where_not_nil_or_empty_semantics
    whitespace_named_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids, :name).new(
      "pages",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      ["page-2"],
      "   "
    )
    empty_named_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids, :name).new(
      "pages",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      ["page-1"],
      ""
    )

    @parent_recording.child_recordings << FakeRecording.new(
      "order-whitespace",
      "RecordingStudio::RecordingStudioOrder",
      whitespace_named_order,
      Time.utc(2024, 1, 8),
      Time.utc(2024, 1, 8)
    )
    @parent_recording.child_recordings << FakeRecording.new(
      "order-empty",
      "RecordingStudio::RecordingStudioOrder",
      empty_named_order,
      Time.utc(2024, 1, 9),
      Time.utc(2024, 1, 9)
    )

    orders = RecordingStudioOrderable::RecordingOrderManager.recording_orders(
      @parent_recording,
      owner: @owner,
      group: :pages,
      named_only: true
    )

    assert_includes orders, whitespace_named_order
    refute_includes orders, empty_named_order
  end

  def test_create_named_recording_order_builds_a_named_order_without_collapsing_to_the_default_scope
    parent_recording = FakeParentRecording.new("folder-2", FakeFolder.new, [@page_one, @page_two, @page_three])
    source_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids, :name).new(
      "pages",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      %w[page-3 page-1],
      "Source list"
    )
    source_order_recording = FakeRecording.new("order-source", "RecordingStudio::RecordingStudioOrder", source_order,
                                               Time.utc(2024, 1, 5), Time.utc(2024, 1, 5))
    parent_recording.child_recordings << source_order_recording
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
      created_order = RecordingStudioOrderable::RecordingOrderManager.create_named_recording_order!(
        parent_recording,
        :pages,
        owner: @owner,
        actor: :actor,
        metadata: { source: "test" },
        name: "Johnny's list",
        source_order_recording_id: "order-source"
      )

      assert_equal parent_recording.id, created_order.parent_recording_id
      assert_equal "pages", created_order.group_key
      assert_equal "Johnny's list", created_order.name
      assert_equal "RecordingOrderManagerTest::FakeOwner", created_order.owner_type
      assert_equal "user-1", created_order.owner_id
      assert_equal %w[page-3 page-1], created_order.ordered_recording_ids
      assert_same parent_recording, created_order.parent_recording_for_validation
      assert_nil created_order.recording_id_for_validation
      assert_equal({ source: "test" }, recorded_arguments[:metadata])
      assert_equal :actor, recorded_arguments[:actor]
      assert_same parent_recording, recorded_arguments[:parent_recording]
      assert_same created_order, recorded_arguments[:order_record]
    end
  end

  def test_duplicate_matching_orders_raise_an_error
    duplicate_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids).new("pages", nil, nil, [])
    duplicate_recording = FakeRecording.new("order-3", "RecordingStudio::RecordingStudioOrder", duplicate_order,
                                            Time.utc(2024, 1, 6), Time.utc(2024, 1, 6))
    @parent_recording.child_recordings << duplicate_recording

    error = assert_raises(RecordingStudioOrderable::RecordingOrderManager::DuplicateOrderError) do
      RecordingStudioOrderable::RecordingOrderManager.default_recording_order(@parent_recording, :pages)
    end

    assert_includes error.message, "Multiple RecordingStudioOrder children exist"
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

  def test_recording_orders_filters_by_group_key
    sections_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids, :name).new(
      "sections",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      ["page-1"],
      nil
    )
    sections_order_recording = FakeRecording.new(
      "order-sections",
      "RecordingStudio::RecordingStudioOrder",
      sections_order,
      Time.utc(2024, 1, 6),
      Time.utc(2024, 1, 6)
    )

    @parent_recording.child_recordings << @scoped_order_recording
    @parent_recording.child_recordings << sections_order_recording

    orders = RecordingStudioOrderable::RecordingOrderManager.recording_orders(
      @parent_recording,
      owner: @owner,
      group: :pages
    )

    assert_equal [@scoped_order], orders
  end

  def test_recording_orders_filters_by_group_type_alias
    @parent_recording.child_recordings << @scoped_order_recording

    orders = RecordingStudioOrderable::RecordingOrderManager.recording_orders(
      @parent_recording,
      owner: @owner,
      group: "Page"
    )

    assert_equal [@scoped_order], orders
  end

  def test_recording_orders_filters_by_orderable_name
    named_order = Struct.new(:group_key, :owner_type, :owner_id, :ordered_recording_ids, :name).new(
      "pages",
      "RecordingOrderManagerTest::FakeOwner",
      "user-1",
      ["page-2"],
      "Primary list"
    )
    @parent_recording.child_recordings << FakeRecording.new(
      "order-named",
      "RecordingStudio::RecordingStudioOrder",
      named_order,
      Time.utc(2024, 1, 6),
      Time.utc(2024, 1, 6)
    )

    orders = RecordingStudioOrderable::RecordingOrderManager.recording_orders(
      @parent_recording,
      owner: @owner,
      group: :pages,
      orderable_name: "Primary list"
    )

    assert_equal [named_order], orders
  end

  def test_recording_orders_raises_for_ambiguous_group_type_alias
    ambiguous_folder_class = Class.new do
      def self.recording_studio_order_group_definitions
        {
          "pages" => { group_key: "pages", allows: ["Page"] },
          "draft_pages" => { group_key: "draft_pages", allows: ["Page"] }
        }
      end

      def self.recording_studio_order_group_definition(name = nil)
        groups = recording_studio_order_group_definitions
        key = name.to_s.presence || "pages"
        definition = groups[key]
        raise KeyError, key if definition.nil?

        definition
      rescue KeyError
        raise RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
              "Unknown order group #{key.inspect}. Available groups: #{groups.keys.join(', ')}"
      end
    end
    parent_recording = FakeParentRecording.new("folder-ambiguous", ambiguous_folder_class.new, [])

    error = assert_raises(RecordingStudioOrderable::RecordingOrderManager::ConfigurationError) do
      RecordingStudioOrderable::RecordingOrderManager.recording_orders(
        parent_recording,
        owner: @owner,
        group: "Page"
      )
    end

    assert_includes error.message, "Ambiguous group filter"
  end

  def test_matching_order_recordings_accepts_equivalent_group_key_and_group_filters
    @parent_recording.child_recordings << @scoped_order_recording

    matches = RecordingStudioOrderable::RecordingOrderManager.matching_order_recordings(
      @parent_recording,
      group_key: :pages,
      group: "Page",
      owner: @owner
    )

    assert_equal [@scoped_order_recording], matches
  end

  def test_matching_order_recordings_raises_for_conflicting_group_filters
    multi_group_folder_class = Class.new do
      def self.recording_studio_order_group_definitions
        {
          "pages" => { group_key: "pages", allows: ["Page"] },
          "sections" => { group_key: "sections", allows: ["Section"] }
        }
      end

      def self.recording_studio_order_group_definition(name = nil)
        groups = recording_studio_order_group_definitions
        key = name.to_s.presence || "pages"
        definition = groups[key]
        raise KeyError, key if definition.nil?

        definition
      rescue KeyError
        raise RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
              "Unknown order group #{key.inspect}. Available groups: #{groups.keys.join(', ')}"
      end
    end
    parent_recording = FakeParentRecording.new("folder-multi-group", multi_group_folder_class.new, [])

    error = assert_raises(RecordingStudioOrderable::RecordingOrderManager::ConfigurationError) do
      RecordingStudioOrderable::RecordingOrderManager.matching_order_recordings(
        parent_recording,
        group_key: :pages,
        group: "Section",
        owner: @owner
      )
    end

    assert_includes error.message, "Conflicting group filters"
  end

  def test_recording_orders_raises_for_unknown_group_filter
    error = assert_raises(RecordingStudioOrderable::RecordingOrderManager::ConfigurationError) do
      RecordingStudioOrderable::RecordingOrderManager.recording_orders(
        @parent_recording,
        owner: @owner,
        group: "UnknownType"
      )
    end

    assert_includes error.message, "Unknown group filter"
    assert_includes error.message, "pages"
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

  def test_find_or_create_recording_order_recovers_from_record_not_unique
    parent_recording = FakeParentRecording.new("folder-2", FakeFolder.new, [@page_one, @page_two])
    existing_order = Struct.new(:id).new("existing-order")
    lookup_count = 0

    parent_recording.define_singleton_method(:record) do |*_args, **_kwargs|
      raise ActiveRecord::RecordNotUnique, "duplicate default order"
    end

    RecordingStudioOrderable::RecordingOrderManager.stub(
      :default_recording_order,
      lambda do |_parent_recording, _group_key = nil, owner: nil|
        lookup_count += 1
        next nil if lookup_count == 1

        assert_equal @owner, owner
        existing_order
      end
    ) do
      with_temporary_recording_order_class do
        result = RecordingStudioOrderable::RecordingOrderManager.find_or_create_recording_order!(
          parent_recording,
          :pages,
          owner: @owner,
          actor: :actor,
          metadata: { source: "test" }
        )

        assert_same existing_order, result
      end
    end

    assert_equal 2, lookup_count
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
    had_constant = RecordingStudio.const_defined?(:RecordingStudioOrder, false)
    original_constant = RecordingStudio.const_get(:RecordingStudioOrder) if had_constant
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

    RecordingStudio.send(:remove_const, :RecordingStudioOrder) if had_constant
    RecordingStudio.const_set(:RecordingStudioOrder, temporary_class)
    yield
  ensure
    RecordingStudio.send(:remove_const, :RecordingStudioOrder) if RecordingStudio.const_defined?(:RecordingStudioOrder,
                                                                                                 false)
    RecordingStudio.const_set(:RecordingStudioOrder, original_constant) if had_constant
  end
end
