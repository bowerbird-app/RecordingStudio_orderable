# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioOrderable.instance_variable_get(:@configuration)
    RecordingStudioOrderable.instance_variable_set(:@configuration, RecordingStudioOrderable::Configuration.new)
  end

  def teardown
    RecordingStudioOrderable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_resolver_wins_when_configured
    RecordingStudioOrderable.configuration.authorization_resolver = lambda { |action:, actor:, **|
      action == :reorder && actor == :ok
    }

    assert RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: :ok, recording: :rec)
    refute RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: :no, recording: :rec)
  end

  def test_allows_when_accessible_is_not_used
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = false

    assert RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: nil, recording: :rec)
  end

  def test_accessible_authorization_is_used_when_available
    accessible = Module.new do
      def self.authorized?(**)
        true
      end
    end
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = true

    stub_constant("RecordingStudioAccessible", accessible) do
      assert RecordingStudioOrderable::Authorization.authorized?(
        action: :reorder,
        actor: :user,
        recording: :rec
      )
    end
  end

  def test_accessible_authorization_denies_blank_actor
    accessible = Module.new do
      def self.authorized?(**)
        true
      end
    end
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = true

    stub_constant("RecordingStudioAccessible", accessible) do
      refute RecordingStudioOrderable::Authorization.authorized?(
        action: :reorder,
        actor: nil,
        recording: :rec
      )
    end
  end

  def test_accessible_authorization_rescues_errors
    accessible = Module.new do
      def self.authorized?(**)
        raise "boom"
      end
    end
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = true

    stub_constant("RecordingStudioAccessible", accessible) do
      refute RecordingStudioOrderable::Authorization.authorized?(
        action: :reorder,
        actor: :user,
        recording: :rec
      )
    end
  end

  def test_use_accessible_is_false_without_constant
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = true

    refute RecordingStudioOrderable::Authorization.use_accessible? unless defined?(RecordingStudioAccessible)
  end

  private

  def stub_constant(name, value)
    if Object.const_defined?(name, false)
      original = Object.const_get(name, false)
      Object.send(:remove_const, name)
      Object.const_set(name, value)
      yield
      Object.send(:remove_const, name)
      Object.const_set(name, original)
    else
      Object.const_set(name, value)
      yield
      Object.send(:remove_const, name)
    end
  end
end
