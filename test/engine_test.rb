# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioOrderable.instance_variable_get(:@configuration)
    RecordingStudioOrderable.instance_variable_set(:@configuration, RecordingStudioOrderable::Configuration.new)
  end

  def teardown
    RecordingStudioOrderable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_load_config_merges_x_configuration
    xcfg = Struct.new(:recording_studio_orderable).new({ log_order_events: true })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config, :config_for_result) do
      def config_for(_name)
        config_for_result
      end
    end.new(app_config, nil)

    find_initializer("recording_studio_orderable.load_config").block.call(app)

    assert_equal true, RecordingStudioOrderable.configuration.log_order_events
  end

  def test_load_config_reads_yaml_when_available
    app_config = Struct.new(:x).new(nil)
    app = Struct.new(:config) do
      def config_for(_name)
        { event_action_prefix: "custom_order" }
      end
    end.new(app_config)

    find_initializer("recording_studio_orderable.load_config").block.call(app)

    assert_equal "custom_order", RecordingStudioOrderable.configuration.event_action_prefix
  end

  def test_load_config_swallows_configuration_errors
    app = Struct.new(:config) do
      def config_for(_name)
        raise "boom"
      end
    end.new(Struct.new(:x).new(nil))

    find_initializer("recording_studio_orderable.load_config").block.call(app)

    assert_equal false, RecordingStudioOrderable.configuration.log_order_events
  end

  def test_integrate_recording_studio_registers_type_and_extension
    to_prepare_blocks = []
    config_stub = Object.new
    config_stub.define_singleton_method(:to_prepare) do |&block|
      to_prepare_blocks << block
    end

    RecordingStudioOrderable::Engine.stub(:config, config_stub) do
      find_initializer("recording_studio_orderable.integrate_recording_studio").block.call
    end

    assert_equal 1, to_prepare_blocks.size
  end

  def test_integrate_recording_studio_prepares_registration_and_extension_inclusion
    to_prepare_blocks = []
    config_stub = Object.new
    register_calls = []
    include_calls = []

    config_stub.define_singleton_method(:to_prepare) do |&block|
      to_prepare_blocks << block
    end

    RecordingStudioOrderable::Engine.stub(:config, config_stub) do
      find_initializer("recording_studio_orderable.integrate_recording_studio").block.call
    end

    RecordingStudio.stub(:register_recordable_type, ->(type) { register_calls << type }) do
      with_temporary_recording_class do |recording_class|
        recording_class.stub(:included_modules, []) do
          recording_class.stub(:include, ->(mod) { include_calls << mod }) do
            to_prepare_blocks.first.call
          end
        end
      end
    end

    assert_equal ["RecordingStudio::RecordingOrder"], register_calls
    assert_equal [RecordingStudioOrderable::RecordingExtensions], include_calls
  end

  private

  def find_initializer(name)
    RecordingStudioOrderable::Engine.initializers.find { |initializer| initializer.name == name }
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
