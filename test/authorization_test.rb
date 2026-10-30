# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioOrderable.configuration
    RecordingStudioOrderable.reset_configuration!
  end

  def teardown
    RecordingStudioOrderable.configuration = @original_configuration
  end

  def test_resolver_replaces_accessible
    called = false
    RecordingStudioOrderable.configuration.accessible_module = module_with_authorized do
      called = true
      false
    end
    RecordingStudioOrderable.configuration.authorization_resolver = lambda { |action:, actor:, **|
      action == :reorder && actor == :ok
    }

    assert RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: :ok, recording: :rec)
    refute RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: :no, recording: :rec)
    refute called
  end

  def test_allows_when_accessible_is_turned_off
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = false

    assert RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: nil, recording: :rec)
  end

  def test_allows_when_resolver_and_accessible_are_missing
    refute defined?(RecordingStudioAccessible)
    RecordingStudioOrderable.configuration.authorization_resolver = nil
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = true
    RecordingStudioOrderable.configuration.accessible_module = nil

    refute RecordingStudioOrderable::Authorization.use_accessible?
    assert RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: nil, recording: nil)
  end

  def test_accessible_module_allows
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = true
    RecordingStudioOrderable.configuration.accessible_module = module_with_authorized { |**| true }

    assert RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: :user, recording: :rec)
  end

  def test_accessible_module_denies_and_receives_blank_actor
    seen = nil
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = true
    RecordingStudioOrderable.configuration.authorization_role = :edit
    RecordingStudioOrderable.configuration.accessible_module = module_with_authorized do |**kwargs|
      seen = kwargs
      false
    end

    refute RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: nil, recording: nil)
    assert_nil seen[:actor]
    assert_nil seen[:recording]
    assert_equal :edit, seen[:role]
  end

  def test_accessible_errors_are_not_rescued
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = true
    RecordingStudioOrderable.configuration.accessible_module = module_with_authorized { |**| raise "boom" }

    error = assert_raises(RuntimeError) do
      RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: :user, recording: :rec)
    end
    assert_equal "boom", error.message
  end

  def test_configured_accessible_module_is_used_when_the_constant_is_absent
    refute defined?(RecordingStudioAccessible)
    RecordingStudioOrderable.configuration.use_recording_studio_accessible = true
    RecordingStudioOrderable.configuration.accessible_module = module_with_authorized { |**| true }

    assert_equal RecordingStudioOrderable.configuration.accessible_module,
                 RecordingStudioOrderable::Authorization.accessible_module
  end

  private

  def module_with_authorized(&block)
    Module.new do
      define_singleton_method(:authorized?, &block)
    end
  end
end
