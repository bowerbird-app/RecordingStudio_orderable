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

    def recording_orders(owner: nil)
      @calls << [:recording_orders, owner]
      [:order]
    end

    def recording_order_for(group_key = nil, owner: nil)
      @calls << [:recording_order_for, group_key, owner]
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

    assert_equal [:order], @instance.recording_orders(owner: owner)
    assert_equal :recording_order, @instance.recording_order_for(:pages, owner: owner)
    assert_equal :created, @instance.find_or_create_recording_order!(:pages, owner: owner)
    assert_equal [:child], @instance.children_for_order_group(:pages)
    assert_equal [:ordered_child], @instance.ordered_children_for(:pages, owner: owner)

    assert_equal(
      [
        [:recording_orders, owner],
        [:recording_order_for, :pages, owner],
        %i[find_or_create_recording_order pages],
        %i[children_for_order_group pages],
        [:ordered_children_for, :pages, owner]
      ],
      @delegate_recording.calls
    )
  end

  def test_instance_methods_raise_when_multiple_recordings_exist
    @instance.recordings = [Object.new, Object.new]

    error = assert_raises(RecordingStudioOrderable::RecordingOrderManager::ConfigurationError) do
      @instance.recording_orders
    end

    assert_includes error.message, "Multiple recordings exist"
  end
end
