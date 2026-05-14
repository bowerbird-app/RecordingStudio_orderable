# frozen_string_literal: true

require "test_helper"
require "active_record"
require_relative "../app/models/recording_studio/recording_studio_order"

class RecordingOrderTest < Minitest::Test
  FakeRecording = Struct.new(:id)
  TemporaryOwner = Struct.new(:id) unless const_defined?(:TemporaryOwner)
  FakeErrorCollector = Struct.new(:messages) do
    def initialize
      super([])
    end

    def add(attribute, message)
      messages << [attribute, message]
    end

    def entries
      messages
    end
  end

  def test_move_to_position_uses_resolved_children_as_the_persistence_baseline
    order = build_order(ordered_recording_ids: %w[page-2 page-1 page-3], name: nil)
    parent_recording = Object.new
    captured = nil

    parent_recording.define_singleton_method(:ordered_children_for) do |_group_key, **|
      [
        FakeRecording.new("page-2"),
        FakeRecording.new("page-1"),
        FakeRecording.new("page-3"),
        FakeRecording.new("page-4")
      ]
    end

    order.define_singleton_method(:persist_updated_ids!) do |ids, actor:, metadata:, action:|
      captured = { ids: ids, actor: actor, metadata: metadata, action: action }
    end

    order.stub(:resolved_parent_recording, parent_recording) do
      order.move_to_position!(moving: "page-3", position: 1, actor: :actor, metadata: { source: "test" })
    end

    assert_equal %w[page-2 page-3 page-1 page-4], captured[:ids]
    assert_equal :actor, captured[:actor]
    assert_equal({ source: "test" }, captured[:metadata])
    assert_equal "moved", captured[:action]
  end

  def test_move_to_position_uses_the_named_list_order_as_the_persistence_baseline
    order = build_order(ordered_recording_ids: %w[page-3 page-1], name: "Johnny's list")
    parent_recording = Object.new
    captured = nil

    order.define_singleton_method(:recordings) do
      [
        Struct.new(:id, :created_at, :updated_at).new(
          "named-recording",
          Time.utc(2024, 1, 2),
          Time.utc(2024, 1, 2)
        )
      ]
    end
    order.define_singleton_method(:persist_updated_ids!) do |ids, actor:, metadata:, action:|
      captured = { ids: ids, actor: actor, metadata: metadata, action: action }
    end

    RecordingStudioOrderable::RecordingOrderManager.stub(
      :eligible_children_for,
      [FakeRecording.new("page-1"), FakeRecording.new("page-2"), FakeRecording.new("page-3")]
    ) do
      order.stub(:resolved_parent_recording, parent_recording) do
        order.move_to_position!(moving: "page-2", position: 0, actor: :actor, metadata: { source: "test" })
      end
    end

    assert_equal %w[page-2 page-3 page-1], captured[:ids]
    assert_equal :actor, captured[:actor]
    assert_equal({ source: "test" }, captured[:metadata])
    assert_equal "moved", captured[:action]
  end

  def test_persist_updated_ids_revises_the_current_order_recording
    order = build_order(ordered_recording_ids: %w[page-2 page-1 page-3], name: "Pages")
    current_recording = Struct.new(:id).new("recording-1")
    revised_recordable = build_order(ordered_recording_ids: [], name: nil)
    revised_recording = Struct.new(:recordable).new(revised_recordable)
    parent_recording = Object.new
    revise_call = nil

    parent_recording.define_singleton_method(:id) { "folder-1" }

    parent_recording.define_singleton_method(:recording_order_recording_for) do |_group_key, **|
      current_recording
    end

    parent_recording.define_singleton_method(:revise) do |recording, actor:, metadata:, &block|
      revise_call = { recording: recording, actor: actor, metadata: metadata }
      block.call(revised_recordable)
      revised_recording
    end

    RecordingStudioOrderable::RecordingOrderManager.stub(:normalize_requested_ids, ->(_parent, _group, ids) { ids }) do
      order.stub(:resolved_parent_recording, parent_recording) do
        result = order.send(
          :persist_updated_ids!,
          %w[page-2 page-3 page-1 page-4],
          actor: :actor,
          metadata: { source: "test" },
          action: "moved"
        )

        assert_same revised_recordable, result
      end
    end

    assert_equal current_recording, revise_call[:recording]
    assert_equal :actor, revise_call[:actor]
    assert_equal({ source: "test" }, revise_call[:metadata])
    assert_equal "folder-1", revised_recordable.parent_recording_id
    assert_same parent_recording, revised_recordable.parent_recording_for_validation
    assert_equal "recording-1", revised_recordable.recording_id_for_validation
    assert_equal "pages", revised_recordable.group_key
    assert_equal "Pages", revised_recordable.name
    assert_equal %w[page-2 page-3 page-1 page-4], revised_recordable.ordered_recording_ids
  end

  def test_persist_updated_ids_revises_the_selected_named_order_recording
    order = build_order(ordered_recording_ids: %w[page-2 page-1 page-3], name: "Johnny's list")
    default_recording = Struct.new(:id).new("default-recording")
    named_recording = Struct.new(:id, :created_at, :updated_at).new(
      "named-recording",
      Time.utc(2024, 1, 2),
      Time.utc(2024, 1, 2)
    )
    revised_recordable = build_order(ordered_recording_ids: [], name: nil)
    revised_recording = Struct.new(:recordable).new(revised_recordable)
    parent_recording = Object.new
    revise_call = nil

    parent_recording.define_singleton_method(:id) { "folder-1" }
    parent_recording.define_singleton_method(:recording_order_recording_for) do |_group_key, **|
      default_recording
    end
    parent_recording.define_singleton_method(:revise) do |recording, actor:, metadata:, &block|
      revise_call = { recording: recording, actor: actor, metadata: metadata }
      block.call(revised_recordable)
      revised_recording
    end

    order.define_singleton_method(:recordings) { [named_recording] }

    RecordingStudioOrderable::RecordingOrderManager.stub(:normalize_requested_ids, ->(_parent, _group, ids) { ids }) do
      result = order.stub(:resolved_parent_recording, parent_recording) do
        order.send(
          :persist_updated_ids!,
          %w[page-2 page-3 page-1 page-4],
          actor: :actor,
          metadata: { source: "test" },
          action: "moved"
        )
      end

      assert_same revised_recordable, result
    end

    assert_equal named_recording, revise_call[:recording]
    assert_equal :actor, revise_call[:actor]
    assert_equal({ source: "test" }, revise_call[:metadata])
    assert_equal "named-recording", revised_recordable.recording_id_for_validation
    assert_equal "Johnny's list", revised_recordable.name
  end

  def test_include_child_appends_the_child_to_the_explicit_ids
    order = build_order(ordered_recording_ids: %w[page-2 page-1 page-3], name: nil)
    captured = capture_persist(order)

    order.define_singleton_method(:normalized_ordered_recording_ids) { %w[page-2 page-1 page-3] }
    order.include_child!(FakeRecording.new("page-4"), actor: :actor, metadata: { source: "test" })

    assert_equal %w[page-2 page-1 page-3 page-4], captured[:ids]
    assert_equal "included", captured[:action]
  end

  def test_remove_child_drops_the_child_from_the_explicit_ids
    order = build_order(ordered_recording_ids: %w[page-2 page-1 page-3], name: nil)
    captured = capture_persist(order)

    order.define_singleton_method(:normalized_ordered_recording_ids) { %w[page-2 page-1 page-3] }
    order.remove_child!("page-1", actor: :actor, metadata: { source: "test" })

    assert_equal %w[page-2 page-3], captured[:ids]
    assert_equal "removed", captured[:action]
  end

  def test_move_before_and_after_use_the_resolved_ordered_children
    order = build_order(ordered_recording_ids: %w[page-2 page-1 page-3], name: nil)
    parent_recording = build_parent_recording_with_children(%w[page-2 page-1 page-3 page-4])
    captured = capture_persist(order)

    order.stub(:resolved_parent_recording, parent_recording) do
      order.move_before!(moving: "page-3", before: "page-1")
    end

    assert_equal %w[page-2 page-3 page-1 page-4], captured[:ids]

    second_capture = capture_persist(order)
    order.stub(:resolved_parent_recording, parent_recording) do
      order.move_after!(moving: "page-1", after: "page-3")
    end

    assert_equal %w[page-2 page-3 page-1 page-4], second_capture[:ids]
  end

  def test_move_to_start_and_end_use_the_resolved_ordered_children
    order = build_order(ordered_recording_ids: %w[page-2 page-1 page-3], name: nil)
    parent_recording = build_parent_recording_with_children(%w[page-2 page-1 page-3 page-4])
    captured = capture_persist(order)

    order.stub(:resolved_parent_recording, parent_recording) do
      order.move_to_start!(moving: "page-4")
    end

    assert_equal %w[page-4 page-2 page-1 page-3], captured[:ids]

    second_capture = capture_persist(order)
    order.stub(:resolved_parent_recording, parent_recording) do
      order.move_to_end!(moving: "page-2")
    end

    assert_equal %w[page-1 page-3 page-4 page-2], second_capture[:ids]
  end

  def test_move_to_position_returns_self_for_an_invalid_position
    order = build_order(ordered_recording_ids: %w[page-2 page-1 page-3], name: nil)
    parent_recording = build_parent_recording_with_children(%w[page-2 page-1 page-3 page-4])
    captured = capture_persist(order)

    result = order.stub(:resolved_parent_recording, parent_recording) do
      order.move_to_position!(moving: "page-3", position: "invalid")
    end

    assert_same order, result
    assert_nil captured[:ids]
  end

  def test_reorder_and_cleanup_delegate_to_persist
    order = build_order(ordered_recording_ids: %w[page-2 page-1 page-3], name: nil)
    reorder_capture = capture_persist(order)

    order.reorder!(ordered_recording_ids: %w[page-3 page-2 page-1], actor: :actor, metadata: { source: "test" })

    assert_equal %w[page-3 page-2 page-1], reorder_capture[:ids]
    assert_equal "reordered", reorder_capture[:action]

    cleanup_capture = capture_persist(order)
    order.define_singleton_method(:normalized_ordered_recording_ids) { %w[page-2 page-1] }
    order.cleanup_missing_children!(actor: :actor, metadata: { source: "test" })

    assert_equal %w[page-2 page-1], cleanup_capture[:ids]
    assert_equal "cleaned", cleanup_capture[:action]
  end

  def test_normalized_ordered_recording_ids_uses_manager_when_a_parent_recording_exists
    order = build_order(ordered_recording_ids: [FakeRecording.new("page-2"), "page-2", "page-1"], name: nil)
    parent_recording = Object.new

    normalized_ids = RecordingStudioOrderable::RecordingOrderManager.stub(
      :normalize_requested_ids,
      lambda do |parent, group_key, ids|
        assert_same parent_recording, parent
        assert_equal "pages", group_key
        assert_equal [FakeRecording.new("page-2"), "page-2", "page-1"].map(&:to_s), ids.map(&:to_s)
        %w[page-2 page-1]
      end
    ) do
      order.stub(:resolved_parent_recording, parent_recording) do
        order.normalized_ordered_recording_ids
      end
    end

    assert_equal %w[page-2 page-1], normalized_ids
  end

  def test_normalized_ordered_recording_ids_without_a_parent_deduplicates_the_array
    order = build_order(ordered_recording_ids: [FakeRecording.new("page-2"), "page-2", nil, "page-1"], name: nil)

    normalized_ids = order.stub(:resolved_parent_recording, nil) do
      order.normalized_ordered_recording_ids
    end

    assert_equal %w[page-2 page-1], normalized_ids
  end

  def test_persist_updated_ids_creates_a_new_order_when_one_does_not_exist
    order = build_order(ordered_recording_ids: %w[page-2 page-1], name: "Pages")
    parent_recording = Object.new
    create_call = nil

    parent_recording.define_singleton_method(:recording_order_recording_for) do |_group_key, **|
      nil
    end

    parent_recording.define_singleton_method(:find_or_create_recording_order!) do |group_key, **options|
      create_call = {
        group_key: group_key,
        owner: options[:owner],
        actor: options[:actor],
        metadata: options[:metadata],
        name: options[:name],
        ordered_recording_ids: options[:ordered_recording_ids]
      }
      :created_order
    end

    RecordingStudioOrderable::RecordingOrderManager.stub(:normalize_requested_ids, ->(_parent, _group, ids) { ids }) do
      result = order.stub(:resolved_parent_recording, parent_recording) do
        order.send(
          :persist_updated_ids!,
          %w[page-2 page-3 page-1],
          actor: :actor,
          metadata: { source: "test" },
          action: "moved"
        )
      end

      assert_equal :created_order, result
    end

    assert_equal "pages", create_call[:group_key]
    assert_equal({ owner_type: nil, owner_id: nil }, create_call[:owner])
    assert_equal :actor, create_call[:actor]
    assert_equal({ source: "test" }, create_call[:metadata])
    assert_equal "Pages", create_call[:name]
    assert_equal %w[page-2 page-3 page-1], create_call[:ordered_recording_ids]
  end

  def test_resolved_owner_and_maybe_log_event_follow_configuration
    order = build_order(
      ordered_recording_ids: %w[page-2 page-1],
      name: nil,
      owner_type: "RecordingOrderTest::TemporaryOwner",
      owner_id: "owner-1"
    )
    owner = TemporaryOwner.new("owner-1")
    parent_recording = Object.new
    log_call = nil
    original_configuration = RecordingStudioOrderable.instance_variable_get(:@configuration)
    RecordingStudioOrderable.instance_variable_set(:@configuration, RecordingStudioOrderable::Configuration.new)
    RecordingStudioOrderable.configuration.log_order_events = true

    TemporaryOwner.define_singleton_method(:find_by) { |id:| owner if id == "owner-1" }
    assert_same owner, order.send(:resolved_owner)

    parent_recording.define_singleton_method(:log_event) do |order_recording, action:, actor:, metadata:|
      log_call = { order_recording: order_recording, action: action, actor: actor, metadata: metadata }
    end

    order.send(:maybe_log_event!, parent_recording, :order_recording, "moved", { source: "test" }, :actor)

    assert_equal :order_recording, log_call[:order_recording]
    assert_equal "recording_order_moved", log_call[:action]
    assert_equal :actor, log_call[:actor]
    assert_equal({ source: "test", group_key: "pages" }, log_call[:metadata])
  ensure
    RecordingStudioOrderable.instance_variable_set(:@configuration, original_configuration)
  end

  def test_resolved_parent_recording_prefers_the_validation_parent
    order = build_order(ordered_recording_ids: %w[page-2 page-1], name: nil)
    parent_recording = Object.new
    order.parent_recording_for_validation = parent_recording

    assert_same parent_recording, order.resolved_parent_recording
  end

  def test_resolved_parent_recording_returns_nil_when_lookup_raises
    order = build_order(ordered_recording_ids: %w[page-2 page-1], name: nil)

    parent_recording = with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find_by) { |**| raise "boom" }
      order.resolved_parent_recording
    end

    assert_nil parent_recording
  end

  def test_group_key_and_scope_validation_helpers_add_errors
    order = build_order(ordered_recording_ids: %w[page-2 page-1], name: nil)
    errors = FakeErrorCollector.new
    matching_recording = Struct.new(:id).new("existing-recording")

    order.define_singleton_method(:errors) { errors }
    order.stub(:resolved_parent_recording, Object.new) do
      RecordingStudioOrderable::RecordingOrderManager.stub(
        :resolve_group_definition!,
        lambda do |_parent, _group|
          raise RecordingStudioOrderable::RecordingOrderManager::ConfigurationError, "unsupported group"
        end
      ) do
        order.send(:group_key_must_be_supported)
      end

      RecordingStudioOrderable::RecordingOrderManager.stub(:matching_order_recordings, [matching_recording]) do
        order.send(:order_scope_must_be_unique)
      end
    end

    assert_includes errors.entries, [:group_key, "unsupported group"]
    assert_includes errors.entries, [:base, "an order already exists for this parent, group, and owner scope"]
  end

  def test_named_orders_do_not_trigger_scope_uniqueness_errors
    order = build_order(ordered_recording_ids: %w[page-2 page-1], name: "Johnny's list")
    errors = FakeErrorCollector.new
    matching_recording = Struct.new(:id).new("existing-recording")

    order.define_singleton_method(:errors) { errors }

    order.stub(:resolved_parent_recording, Object.new) do
      RecordingStudioOrderable::RecordingOrderManager.stub(:matching_order_recordings, [matching_recording]) do
        order.send(:order_scope_must_be_unique)
      end
    end

    refute_includes errors.entries, [:base, "an order already exists for this parent, group, and owner scope"]
  end

  def test_uuid_and_duplicate_validations_add_errors
    order = build_order(ordered_recording_ids: ["not-a-uuid", "not-a-uuid"], name: nil)
    errors = FakeErrorCollector.new

    order.define_singleton_method(:errors) { errors }
    order.send(:ordered_recording_ids_must_be_unique)
    order.send(:ordered_recording_ids_must_be_uuids)

    assert_includes errors.entries, [:ordered_recording_ids, "must not contain duplicates"]
    assert_equal 2, (errors.entries.count do |entry|
      entry == [:ordered_recording_ids, "must contain UUID values"]
    end)
  end

  def test_eligible_child_validation_rejects_missing_self_and_cross_scope_recordings
    order = build_order(
      ordered_recording_ids: %w[
        11111111-1111-1111-1111-111111111111
        22222222-2222-2222-2222-222222222222
        33333333-3333-3333-3333-333333333333
        44444444-4444-4444-4444-444444444444
        55555555-5555-5555-5555-555555555555
      ],
      name: nil,
      recording_id_for_validation: "recording-self"
    )
    errors = FakeErrorCollector.new
    parent_recording = Struct.new(:id, :root_recording_id).new("folder-1", "root-1")
    self_recording = Struct.new(:id, :parent_recording_id, :root_recording_id, :recordable_type).new(
      "22222222-2222-2222-2222-222222222222", "folder-1", "root-1", "Page"
    )
    wrong_parent = Struct.new(:id, :parent_recording_id, :root_recording_id, :recordable_type).new(
      "33333333-3333-3333-3333-333333333333", "other-folder", "root-1", "Page"
    )
    wrong_root = Struct.new(:id, :parent_recording_id, :root_recording_id, :recordable_type).new(
      "44444444-4444-4444-4444-444444444444", "folder-1", "other-root", "Page"
    )
    wrong_type = Struct.new(:id, :parent_recording_id, :root_recording_id, :recordable_type).new(
      "55555555-5555-5555-5555-555555555555", "folder-1", "root-1", "Report"
    )

    order.define_singleton_method(:errors) { errors }
    order.define_singleton_method(:recordings) { [self_recording] }

    RecordingStudioOrderable::RecordingOrderManager.stub(
      :resolve_group_definition!,
      { group_key: "pages", allows: ["Page"] }
    ) do
      with_temporary_recording_class do |recording_class|
        recording_class.define_singleton_method(:where) do |**|
          [self_recording, wrong_parent, wrong_root, wrong_type]
        end

        order.stub(:resolved_parent_recording, parent_recording) do
          order.send(:ordered_recording_ids_must_belong_to_eligible_children)
        end
      end
    end

    assert_includes errors.entries, [:ordered_recording_ids, "must reference existing RecordingStudio::Recording rows"]
    assert_includes errors.entries, [:ordered_recording_ids, "cannot include the RecordingStudioOrder recording itself"]
    assert_includes(
      errors.entries,
      [:ordered_recording_ids, "must only include direct children of the same parent recording"]
    )
    assert_includes errors.entries, [:ordered_recording_ids, "must stay within the same root recording"]
    assert_includes errors.entries, [:ordered_recording_ids, "must only include allowed recordable types for the group"]
  end

  private

  def build_order(ordered_recording_ids:, name:, owner_type: nil, owner_id: nil, recording_id_for_validation: nil)
    state = {
      parent_recording_id: "folder-1",
      group_key: "pages",
      ordered_recording_ids: ordered_recording_ids,
      name: name,
      owner_type: owner_type,
      owner_id: owner_id,
      parent_recording_for_validation: nil,
      recording_id_for_validation: recording_id_for_validation
    }

    RecordingStudio::RecordingStudioOrder.allocate.tap do |order|
      state.each_key do |attribute|
        order.define_singleton_method(attribute) { state[attribute] }
        order.define_singleton_method("#{attribute}=") { |value| state[attribute] = value }
      end
    end
  end

  def build_parent_recording_with_children(ids)
    Object.new.tap do |parent_recording|
      parent_recording.define_singleton_method(:ordered_children_for) do |_group_key, **|
        ids.map { |id| FakeRecording.new(id) }
      end
    end
  end

  def capture_persist(order)
    captured = {}
    order.define_singleton_method(:persist_updated_ids!) do |ids, actor:, metadata:, action:|
      captured[:ids] = ids
      captured[:actor] = actor
      captured[:metadata] = metadata
      captured[:action] = action
    end
    captured
  end

  def with_temporary_recording_class
    had_constant = RecordingStudio.const_defined?(:Recording, false)
    original_constant = RecordingStudio.const_get(:Recording) if had_constant
    temporary_class = Class.new

    RecordingStudio.send(:remove_const, :Recording) if had_constant
    RecordingStudio.const_set(:Recording, temporary_class)
    yield temporary_class
  ensure
    RecordingStudio.send(:remove_const, :Recording) if RecordingStudio.const_defined?(:Recording, false)
    RecordingStudio.const_set(:Recording, original_constant) if had_constant
  end
end
