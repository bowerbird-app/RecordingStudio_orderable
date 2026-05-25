# frozen_string_literal: true

require "test_helper"

class OrderableRecordableTest < Minitest::Test
  class AllowedPage
    def self.name
      "OrderableRecordableTest::AllowedPage"
    end
  end

  class FakeRecordable
    class << self
      # rubocop:disable Naming/PredicatePrefix
      define_method(:has_many) { |*| }
      # rubocop:enable Naming/PredicatePrefix

      def class_attribute(name, default:, **options)
        _instance_writer = options.fetch(:instance_writer, nil)
        singleton_class.send(:define_method, name) do
          instance_variable_get("@#{name}") || default
        end
        singleton_class.send(:define_method, "#{name}=") do |value|
          instance_variable_set("@#{name}", value)
        end
        public_send("#{name}=", default)
      end
    end

    include RecordingStudioOrderable::OrderableRecordable

    attr_accessor :recordings
  end

  class DelegateRecording
    attr_reader :calls

    def initialize
      @calls = []
    end

    def recording_orders(owner: nil, group: nil, orderable_name: nil, named_only: false)
      @calls << [:recording_orders, owner, group, orderable_name, named_only]
      [:order]
    end

    def default_recording_order(group_key = nil, owner: nil)
      @calls << [:default_recording_order, group_key, owner]
      :recording_order
    end

    def find_or_create_recording_order!(group_key = nil, **)
      @calls << [:find_or_create_recording_order, group_key]
      :created
    end

    def children_for_order_group(group_key = nil)
      @calls << [:children_for_order_group, group_key]
      [:child]
    end

    def ordered_children_for(group_key = nil, owner: nil)
      @calls << [:ordered_children_for, group_key, owner]
      [:ordered_child]
    end
  end

  def setup
    FakeRecordable.recording_studio_order_group_definitions = {}
    @instance = FakeRecordable.new
    @delegate_recording = DelegateRecording.new
  end

  def test_recording_studio_order_group_normalizes_definition_values
    FakeRecordable.recording_studio_order_group(:pages, allows: [AllowedPage, "Page"])

    assert_equal(
      { group_key: "pages", allows: %w[OrderableRecordableTest::AllowedPage Page] },
      FakeRecordable.recording_studio_order_group_definition(:pages)
    )
    assert_equal "pages", FakeRecordable.default_recording_studio_order_group
  end

  def test_recording_studio_order_group_definition_raises_for_unknown_group
    FakeRecordable.recording_studio_order_group(:pages, allows: ["Page"])

    error = assert_raises(RecordingStudioOrderable::RecordingOrderManager::ConfigurationError) do
      FakeRecordable.recording_studio_order_group_definition(:missing)
    end

    assert_includes error.message, "Unknown order group"
    assert_includes error.message, "pages"
  end

  def test_default_group_requires_explicit_name_when_multiple_groups_exist
    FakeRecordable.recording_studio_order_group(:pages, allows: ["Page"])
    FakeRecordable.recording_studio_order_group(:assets, allows: ["Asset"])

    error = assert_raises(RecordingStudioOrderable::RecordingOrderManager::ConfigurationError) do
      FakeRecordable.default_recording_studio_order_group
    end

    assert_includes error.message, "group name is required"
  end

  def test_recording_orders_returns_empty_array_without_current_recording
    @instance.recordings = []

    assert_equal [], @instance.recording_orders
  end

  def test_instance_methods_delegate_to_the_single_current_recording
    owner = Struct.new(:id).new("owner-1")
    @instance.recordings = [@delegate_recording]

    assert_equal [:order], @instance.recording_orders(owner: owner, group: "Page", orderable_name: "Main list")
    assert_equal :recording_order, @instance.default_recording_order(:pages, owner: owner)
    assert_equal :created, @instance.find_or_create_recording_order!(:pages, owner: owner)
    assert_equal [:child], @instance.children_for_order_group(:pages)
    assert_equal [:ordered_child], @instance.ordered_children_for(:pages, owner: owner)

    assert_equal(
      [
        [:recording_orders, owner, "Page", "Main list", false],
        [:default_recording_order, :pages, owner],
        %i[find_or_create_recording_order pages],
        %i[children_for_order_group pages],
        [:ordered_children_for, :pages, owner]
      ],
      @delegate_recording.calls
    )
  end

  def test_instance_methods_use_the_latest_recording_when_multiple_exist
    older_recording = build_recording_snapshot("older", Time.utc(2024, 1, 1))
    newer_recording = build_recording_snapshot("newer", Time.utc(2024, 1, 2))
    @instance.recordings = [older_recording, newer_recording]

    assert_equal ["newer"], @instance.recording_orders
    assert_equal "newer", @instance.default_recording_order(:pages)
    assert_equal "newer", @instance.find_or_create_recording_order!(:pages)
    assert_equal ["newer"], @instance.children_for_order_group(:pages)
    assert_equal ["newer"], @instance.ordered_children_for(:pages)
  end

  def test_instance_methods_return_empty_array_without_any_recordings
    @instance.recordings = []

    assert_equal [], @instance.recording_orders
  end

  private

  def build_recording_snapshot(label, timestamp)
    Struct.new(:id, :created_at, :updated_at).new(label, timestamp, timestamp).tap do |recording|
      recording.define_singleton_method(:recording_orders) { |**| [id] }
      recording.define_singleton_method(:default_recording_order) { |*, **| id }
      recording.define_singleton_method(:find_or_create_recording_order!) { |*, **| id }
      recording.define_singleton_method(:children_for_order_group) { |*| [id] }
      recording.define_singleton_method(:ordered_children_for) { |*, **| [id] }
    end
  end
end
