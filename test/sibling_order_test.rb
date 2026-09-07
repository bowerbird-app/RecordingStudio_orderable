# frozen_string_literal: true

require "test_helper"

class SiblingOrderTest < Minitest::Test
  class FakeRelation
    def initialize(records)
      @records = records
    end

    def where(conditions)
      types = Array(conditions[:recordable_type])
      ids = Array(conditions[:id])
      selected = @records
      selected = selected.select { |record| types.include?(record.recordable_type) } if types.any?
      selected = selected.select { |record| ids.include?(record.id) } if ids.any? && conditions.key?(:id)
      self.class.new(selected)
    end

    def reorder(*)
      ordered = @records.sort_by do |record|
        [record.recording_studio_orderable_position || Float::INFINITY, record.created_at || Time.at(0), record.id.to_s]
      end
      self.class.new(ordered)
    end

    def to_a
      @records
    end

    def map(&)
      @records.map(&)
    end
  end

  class FakeRecording
    class << self
      attr_accessor :records

      def transaction
        yield
      end

      def quoted_table_name
        "recording_studio_recordings"
      end

      def where(conditions)
        FakeRelation.new(records.values).where(conditions)
      end
    end

    attr_accessor :id, :recordable_type, :created_at, :recording_studio_orderable_position,
                  :logged_events, :child_records

    def initialize(id:, recordable_type: "Page", created_at: Time.at(id.to_s.ord),
                   recording_studio_orderable_position: nil, child_records: [])
      @id = id
      @recordable_type = recordable_type
      @created_at = created_at
      @recording_studio_orderable_position = recording_studio_orderable_position
      @logged_events = []
      @child_records = child_records
      self.class.records ||= {}
      self.class.records[id] = self
    end

    def child_recordings
      FakeRelation.new(child_records)
    end

    def capability_options(_name)
      { allows: ["Page"] }
    end

    def reload
      self
    end

    # rubocop:disable Naming/PredicateMethod
    def update!(attributes)
      self.recording_studio_orderable_position = attributes[:recording_studio_orderable_position]
      true
    end
    # rubocop:enable Naming/PredicateMethod

    def log_event!(**attributes)
      logged_events << attributes
    end
  end

  def setup
    FakeRecording.records = {}
    @original_configuration = RecordingStudioOrderable.instance_variable_get(:@configuration)
    RecordingStudioOrderable.instance_variable_set(:@configuration, RecordingStudioOrderable::Configuration.new)
  end

  def teardown
    FakeRecording.records = {}
    RecordingStudioOrderable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_ignores_stale_ids_and_appends_missing_children
    first = FakeRecording.new(id: "a", created_at: Time.at(1), recording_studio_orderable_position: 2)
    second = FakeRecording.new(id: "b", created_at: Time.at(2), recording_studio_orderable_position: 1)
    parent = FakeRecording.new(id: "folder", recordable_type: "Folder", child_records: [first, second])

    RecordingStudioOrderable::SiblingOrder.new(parent).reorder!(
      ordered_recording_ids: %w[missing b],
      actor: :admin
    )

    assert_equal 0, second.recording_studio_orderable_position
    assert_equal 1, first.recording_studio_orderable_position
  end

  def test_skips_event_when_logging_disabled
    child = FakeRecording.new(id: "a")
    parent = FakeRecording.new(id: "folder", recordable_type: "Folder", child_records: [child])
    RecordingStudioOrderable.configuration.log_order_events = false

    RecordingStudioOrderable::SiblingOrder.new(parent).reorder!(ordered_recording_ids: ["a"])

    assert_empty parent.logged_events
  end

  def test_allows_all_children_when_allows_is_blank
    page = FakeRecording.new(id: "page", recordable_type: "Page")
    note = FakeRecording.new(id: "note", recordable_type: "Note")
    parent = FakeRecording.new(id: "folder", recordable_type: "Folder", child_records: [page, note])
    def parent.capability_options(_name)
      {}
    end

    children = RecordingStudioOrderable::SiblingOrder.new(parent).children.to_a

    assert_equal %w[note page], children.map(&:id).sort
  end

  def test_move_clamps_index
    first = FakeRecording.new(id: "a", recording_studio_orderable_position: 0)
    second = FakeRecording.new(id: "b", recording_studio_orderable_position: 1)
    parent = FakeRecording.new(id: "folder", recordable_type: "Folder", child_records: [first, second])

    RecordingStudioOrderable::SiblingOrder.new(parent).move!("a", to_index: 99)

    assert_equal 1, first.recording_studio_orderable_position
    assert_equal 0, second.recording_studio_orderable_position
  end

  def test_append_moves_a_child_to_the_end_of_a_non_empty_list
    first = FakeRecording.new(id: "a", recording_studio_orderable_position: 0)
    second = FakeRecording.new(id: "b", recording_studio_orderable_position: 1)
    third = FakeRecording.new(id: "c", recording_studio_orderable_position: 2)
    parent = FakeRecording.new(id: "folder", recordable_type: "Folder", child_records: [first, second, third])

    RecordingStudioOrderable::SiblingOrder.new(parent).append!("a", actor: :admin)

    assert_equal 0, second.recording_studio_orderable_position
    assert_equal 1, third.recording_studio_orderable_position
    assert_equal 2, first.recording_studio_orderable_position
    assert_equal "a", parent.logged_events.first[:metadata][:moving_recording_id]
    assert_equal 2, parent.logged_events.first[:metadata][:to_index]
  end

  def test_append_on_a_sole_child_assigns_position_zero
    only_child = FakeRecording.new(id: "a", recording_studio_orderable_position: nil)
    parent = FakeRecording.new(id: "folder", recordable_type: "Folder", child_records: [only_child])

    RecordingStudioOrderable::SiblingOrder.new(parent).append!(only_child)

    assert_equal 0, only_child.recording_studio_orderable_position
    assert_equal ["a"], parent.logged_events.first[:metadata][:ordered_recording_ids]
  end

  def test_append_on_empty_children_does_not_raise
    parent = FakeRecording.new(id: "folder", recordable_type: "Folder", child_records: [])

    RecordingStudioOrderable::SiblingOrder.new(parent).append!("missing")

    assert parent.logged_events.first
    assert_equal "missing", parent.logged_events.first[:metadata][:moving_recording_id]
    assert_equal 0, parent.logged_events.first[:metadata][:to_index]
  end

  def test_append_of_the_last_child_keeps_order
    first = FakeRecording.new(id: "a", recording_studio_orderable_position: 0)
    second = FakeRecording.new(id: "b", recording_studio_orderable_position: 1)
    parent = FakeRecording.new(id: "folder", recordable_type: "Folder", child_records: [first, second])

    RecordingStudioOrderable::SiblingOrder.new(parent).append!("b")

    assert_equal 0, first.recording_studio_orderable_position
    assert_equal 1, second.recording_studio_orderable_position
  end

  def test_reads_capability_options_from_recording_studio_when_needed
    child = FakeRecording.new(id: "a")
    parent = FakeRecording.new(id: "folder", recordable_type: "Folder", child_records: [child])
    def parent.capability_options(_name)
      raise NoMethodError
    end

    def parent.respond_to?(name, include_private: false)
      return false if name == :capability_options

      super
    end

    RecordingStudio.stub(:capability_options, { allows: ["Page"] }) do
      assert_equal [child], RecordingStudioOrderable::SiblingOrder.new(parent).children.to_a
    end
  end
end
