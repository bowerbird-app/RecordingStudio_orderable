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
    xcfg = Struct.new(:recording_studio_orderable).new(
      { log_order_events: false, event_action: "custom_order" }
    )
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config, :config_for_result) do
      def config_for(_name)
        config_for_result
      end
    end.new(app_config, nil)

    find_initializer("recording_studio_orderable.load_config").block.call(app)

    assert_equal false, RecordingStudioOrderable.configuration.log_order_events
    assert_equal "custom_order", RecordingStudioOrderable.configuration.event_action
  end

  def test_load_config_reads_yaml_when_available
    app_config = Struct.new(:x).new(nil)
    app = Struct.new(:config) do
      def config_for(_name)
        { event_action: "custom_order" }
      end
    end.new(app_config)

    find_initializer("recording_studio_orderable.load_config").block.call(app)

    assert_equal "custom_order", RecordingStudioOrderable.configuration.event_action
  end

  def test_load_config_ignores_missing_yaml_file
    app = Struct.new(:config) do
      def config_for(_name)
        raise "Could not load configuration. No such file - /tmp/recording_studio_orderable.yml"
      end
    end.new(Struct.new(:x).new(nil))

    find_initializer("recording_studio_orderable.load_config").block.call(app)

    assert_equal true, RecordingStudioOrderable.configuration.log_order_events
  end

  def test_load_config_raises_for_invalid_configuration
    app = Struct.new(:config) do
      def config_for(_name)
        raise "boom"
      end
    end.new(Struct.new(:x).new(nil))

    error = assert_raises(RecordingStudioOrderable::ConfigurationLoadError) do
      find_initializer("recording_studio_orderable.load_config").block.call(app)
    end

    assert_includes error.message, "Invalid recording_studio_orderable configuration"
    assert_includes error.message, "boom"
  end

  def test_load_yaml_config_returns_nil_when_file_is_missing
    app = Object.new
    def app.config_for(_name)
      raise "Could not load configuration. No such file - missing.yml"
    end

    assert_nil RecordingStudioOrderable::Engine.load_yaml_config(app)
  end

  def test_importmap_initializer_is_registered
    initializer = find_initializer("recording_studio_orderable.importmap")

    refute_nil initializer
  end

  private

  def find_initializer(name)
    RecordingStudioOrderable::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
