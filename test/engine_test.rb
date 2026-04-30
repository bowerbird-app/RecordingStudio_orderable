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

  private

  def find_initializer(name)
    RecordingStudioOrderable::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
