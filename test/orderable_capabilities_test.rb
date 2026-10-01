# frozen_string_literal: true

require "test_helper"

class OrderableCapabilitiesTest < Minitest::Test
  class FakeRelation
    def initialize(records)
      @records = records
    end

    def where(conditions)
      types = Array(conditions[:recordable_type])
      selected = types.any? ? @records.select { |record| types.include?(record.recordable_type) } : @records
      self.class.new(selected)
    end

    def reorder(*)
      self
    end

    def to_a
      @records
    end

    def map(&)
      @records.map(&)
    end
  end

  class FakeRecording
    include RecordingStudio::Orderable::Capabilities::Orderable::RecordingMethods

    class << self
      attr_accessor :records

      def transaction
        yield
      end

      def quoted_table_name
        "recording_studio_recordings"
      end

      def where(conditions)
        ids = Array(conditions[:id])
        FakeRelation.new(records.values.select { |record| ids.include?(record.id) })
      end
    end

    attr_accessor :id, :parent_recording_id, :recordable_type, :created_at,
                  :recording_studio_orderable_position, :logged_events, :updated_with, :reloaded,
                  :child_records

    def initialize(id:, **attrs)
      @id = id
      @parent_recording_id = attrs[:parent_recording_id]
      @recordable_type = attrs.fetch(:recordable_type, "Folder")
      @created_at = attrs.fetch(:created_at, Time.at(0))
      @recording_studio_orderable_position = attrs[:recording_studio_orderable_position]
      @child_records = attrs.fetch(:child_records, [])
      @logged_events = []
      self.class.records ||= {}
      self.class.records[id] = self
    end

    def child_recordings
      FakeRelation.new(child_records)
    end

    def with_lock(&)
      self.class.transaction(&)
    end

    def reload
      self.reloaded = true
      self
    end

    # rubocop:disable Naming/PredicateMethod
    def update!(attributes)
      self.updated_with = attributes
      self.recording_studio_orderable_position = attributes[:recording_studio_orderable_position]
      true
    end
    # rubocop:enable Naming/PredicateMethod

    def log_event!(**attributes)
      logged_events << attributes
    end

    def capability_options(name)
      raise "unexpected capability" unless name == :orderable

      { allows: ["Page"] }
    end

    def assert_capability!(capability)
      raise "unexpected capability" unless capability == :orderable
    end
  end

  def setup
    FakeRecording.records = {}
    @original_configuration = RecordingStudioOrderable.instance_variable_get(:@configuration)
    RecordingStudioOrderable.instance_variable_set(:@configuration, RecordingStudioOrderable::Configuration.new)
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = false
  end

  def teardown
    FakeRecording.records = {}
    RecordingStudioOrderable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_capability_builder_registers_capability_options
    applied = []
    base = Struct.new(:name).new("Folder")

    RecordingStudio.stub(:enable_capability, ->(*args, **kwargs) { applied << [:enable, args, kwargs] }) do
      RecordingStudio.stub(:set_capability_options, ->(*args, **kwargs) { applied << [:options, args, kwargs] }) do
        RecordingStudio::Orderable::Capabilities::Orderable.apply_capability(base, allows: ["Page"])
      end
    end

    assert_equal [:enable, [:orderable], { on: "Folder" }], applied.first
    assert_equal [:options, [:orderable], { on: "Folder", allows: ["Page"] }], applied.last
  end

  def test_to_normalizes_class_allows
    options = RecordingStudio::Orderable::Capabilities::Orderable.capability_options(allows: [String])

    assert_equal ["String"], options[:allows]
  end

  def test_to_returns_a_concern_that_applies_on_include
    applied = []
    base = Class.new do
      def self.name
        "Folder"
      end
    end

    RecordingStudio.stub(:enable_capability, ->(*args, **kwargs) { applied << [:enable, args, kwargs] }) do
      RecordingStudio.stub(:set_capability_options, ->(*args, **kwargs) { applied << [:options, args, kwargs] }) do
        base.include(RecordingStudio::Capabilities::Orderable.to(allows: ["Page"]))
      end
    end

    assert_equal "Folder", applied.first.last[:on]
  end

  def test_orderable_capability_registration_has_source_without_child_recordables
    registration = RecordingStudio.registered_capabilities.fetch(:orderable)

    assert_equal "recording_studio_orderable", registration.fetch(:source)
    assert_empty registration.fetch(:child_recordables)
  end

  def test_reorder_assigns_positions_and_logs_event
    children = [
      FakeRecording.new(id: "b", recordable_type: "Page", recording_studio_orderable_position: 0),
      FakeRecording.new(id: "a", recordable_type: "Page", recording_studio_orderable_position: 1)
    ]
    parent = FakeRecording.new(id: "folder", child_records: children)

    RecordingStudioOrderable.stub(:authorized?, true) do
      parent.recording_studio_orderable_reorder!(
        ordered_recording_ids: %w[a b],
        actor: :admin,
        metadata: { source: "test" }
      )
    end

    assert_equal 0, children[1].recording_studio_orderable_position
    assert_equal 1, children[0].recording_studio_orderable_position
    assert parent.reloaded
    assert_equal "reordered", parent.logged_events.first[:action]
    assert_equal %w[a b], parent.logged_events.first[:metadata][:ordered_recording_ids]
  end

  def test_move_reinserts_child_and_authorizes
    children = [
      FakeRecording.new(id: "a", recordable_type: "Page", recording_studio_orderable_position: 0),
      FakeRecording.new(id: "b", recordable_type: "Page", recording_studio_orderable_position: 1),
      FakeRecording.new(id: "c", recordable_type: "Page", recording_studio_orderable_position: 2)
    ]
    parent = FakeRecording.new(id: "folder", child_records: children)

    RecordingStudioOrderable.stub(:authorized?, true) do
      parent.recording_studio_orderable_move!(children[2], to_index: 0, actor: :admin)
    end

    assert_equal 0, children[2].recording_studio_orderable_position
    assert_equal "c", parent.logged_events.first[:metadata][:moving_recording_id]
  end

  def test_append_moves_child_to_end_and_authorizes
    children = [
      FakeRecording.new(id: "a", recordable_type: "Page", recording_studio_orderable_position: 0),
      FakeRecording.new(id: "b", recordable_type: "Page", recording_studio_orderable_position: 1),
      FakeRecording.new(id: "c", recordable_type: "Page", recording_studio_orderable_position: 2)
    ]
    parent = FakeRecording.new(id: "folder", child_records: children)

    RecordingStudioOrderable.stub(:authorized?, true) do
      parent.recording_studio_orderable_append!(children[0], actor: :admin)
    end

    assert_equal 2, children[0].recording_studio_orderable_position
    assert_equal 0, children[1].recording_studio_orderable_position
    assert_equal 1, children[2].recording_studio_orderable_position
    assert_equal "a", parent.logged_events.first[:metadata][:moving_recording_id]
    assert_equal 2, parent.logged_events.first[:metadata][:to_index]
  end

  def test_move_raises_invalid_child_when_recording_is_not_a_direct_child
    child = FakeRecording.new(id: "a", recordable_type: "Page", recording_studio_orderable_position: 0)
    stranger = FakeRecording.new(id: "stranger", recordable_type: "Page")
    parent = FakeRecording.new(id: "folder", child_records: [child])

    RecordingStudioOrderable.stub(:authorized?, true) do
      error = assert_raises(RecordingStudioOrderable::InvalidChild) do
        parent.recording_studio_orderable_move!(stranger, to_index: 0, actor: :admin)
      end

      assert_match "not an eligible child of the orderable parent", error.message
    end

    assert_empty parent.logged_events
    assert_equal 0, child.recording_studio_orderable_position
  end

  def test_append_raises_invalid_child_when_recording_is_missing
    parent = FakeRecording.new(id: "folder", child_records: [])

    RecordingStudioOrderable.stub(:authorized?, true) do
      error = assert_raises(RecordingStudioOrderable::InvalidChild) do
        parent.recording_studio_orderable_append!("missing", actor: :admin)
      end

      assert_match "missing", error.message
      assert_match "not an eligible child of the orderable parent", error.message
    end

    assert_empty parent.logged_events
  end

  def test_move_and_append_raise_invalid_child_when_allows_excludes_the_child
    page = FakeRecording.new(id: "page", recordable_type: "Page", recording_studio_orderable_position: 0)
    note = FakeRecording.new(id: "note", recordable_type: "Note", recording_studio_orderable_position: 4)
    parent = FakeRecording.new(id: "folder", child_records: [page, note])

    RecordingStudioOrderable.stub(:authorized?, true) do
      assert_raises(RecordingStudioOrderable::InvalidChild) do
        parent.recording_studio_orderable_move!(note, to_index: 0, actor: :admin)
      end
      assert_raises(RecordingStudioOrderable::InvalidChild) do
        parent.recording_studio_orderable_append!("note", actor: :admin)
      end
    end

    assert_empty parent.logged_events
    assert_equal 0, page.recording_studio_orderable_position
    assert_equal 4, note.recording_studio_orderable_position
  end

  def test_reorder_ignores_stale_and_non_eligible_ids
    page = FakeRecording.new(id: "page", recordable_type: "Page", recording_studio_orderable_position: 1)
    note = FakeRecording.new(id: "note", recordable_type: "Note", recording_studio_orderable_position: 8)
    parent = FakeRecording.new(id: "folder", child_records: [page, note])

    RecordingStudioOrderable.stub(:authorized?, true) do
      parent.recording_studio_orderable_reorder!(
        ordered_recording_ids: %w[missing note page],
        actor: :admin
      )
    end

    assert_equal 0, page.recording_studio_orderable_position
    assert_equal 8, note.recording_studio_orderable_position
    assert_equal ["page"], parent.logged_events.first[:metadata][:ordered_recording_ids]
    assert_equal "reordered", parent.logged_events.first[:action]
  end

  def test_append_raises_when_unauthorized
    parent = FakeRecording.new(id: "folder", child_records: [])

    RecordingStudioOrderable.stub(:authorized?, false) do
      error = assert_raises(ArgumentError) do
        parent.recording_studio_orderable_append!("a", actor: :admin)
      end

      assert_includes error.message, "Not authorized to reorder"
    end
  end

  def test_reorder_raises_when_unauthorized
    parent = FakeRecording.new(id: "folder", child_records: [])

    RecordingStudioOrderable.stub(:authorized?, false) do
      error = assert_raises(ArgumentError) do
        parent.recording_studio_orderable_reorder!(ordered_recording_ids: [], actor: :admin)
      end

      assert_includes error.message, "Not authorized to reorder"
    end
  end

  def test_children_returns_sibling_order_relation
    child = FakeRecording.new(id: "a", recordable_type: "Page")
    parent = FakeRecording.new(id: "folder", child_records: [child])

    assert_equal [child], parent.recording_studio_orderable_children.to_a
  end
end
