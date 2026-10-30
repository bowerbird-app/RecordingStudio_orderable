# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioOrderable.configuration
    RecordingStudioOrderable.reset_configuration!
  end

  def teardown
    RecordingStudioOrderable.configuration = @original_configuration
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

  def test_load_config_wraps_invalid_layout
    app = Struct.new(:config) do
      def config_for(_name)
        { layout: Object.new }
      end
    end.new(Struct.new(:x).new(nil))

    error = assert_raises(RecordingStudioOrderable::ConfigurationLoadError) do
      find_initializer("recording_studio_orderable.load_config").block.call(app)
    end

    assert_includes error.message, "Invalid recording_studio_orderable configuration"
  end

  def test_load_config_wraps_psych_and_type_errors
    failures = [
      psych_syntax_error,
      Psych::Exception.new("bad yaml"),
      Psych::DisallowedClass.new("load", "Date"),
      TypeError.new("bad type"),
      ArgumentError.new("bad argument")
    ]
    failures.each do |failure|
      app = Struct.new(:config) do
        define_method(:config_for) { |_name| raise failure }
      end.new(Struct.new(:x).new(nil))

      error = assert_raises(RecordingStudioOrderable::ConfigurationLoadError) do
        find_initializer("recording_studio_orderable.load_config").block.call(app)
      end

      assert_includes error.message, failure.message
    end
  end

  def test_load_config_does_not_wrap_unrelated_errors
    app = Struct.new(:config) do
      def config_for(_name)
        raise "boom"
      end
    end.new(Struct.new(:x).new(nil))

    error = assert_raises(RuntimeError) do
      find_initializer("recording_studio_orderable.load_config").block.call(app)
    end

    assert_equal "boom", error.message
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

  def psych_syntax_error
    Psych::SyntaxError.new("recording_studio_orderable.yml", 1, 1, 0, "bad indent", "context")
  end
end
