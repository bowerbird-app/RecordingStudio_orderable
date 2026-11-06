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

  def test_delegates_to_accessible_with_configured_role
    seen = nil
    RecordingStudioOrderable.configuration.authorization_role = :edit

    RecordingStudioAccessible.stub(:authorized?, lambda { |**kwargs|
      seen = kwargs
      true
    }) do
      assert RecordingStudioOrderable::Authorization.authorized?(
        action: :reorder,
        actor: :user,
        recording: :rec,
        controller: :ctrl
      )
    end

    assert_equal :user, seen[:actor]
    assert_equal :rec, seen[:recording]
    assert_equal :edit, seen[:role]
    refute seen.key?(:action)
    refute seen.key?(:controller)
  end

  def test_denies_when_accessible_returns_false
    RecordingStudioAccessible.stub(:authorized?, false) do
      refute RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: :user, recording: :rec)
    end
  end

  def test_denies_when_accessible_returns_nil
    RecordingStudioAccessible.stub(:authorized?, nil) do
      refute RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: :user, recording: :rec)
    end
  end

  def test_passes_blank_actor_through_to_accessible
    seen = nil
    RecordingStudioAccessible.stub(:authorized?, lambda { |**kwargs|
      seen = kwargs
      false
    }) do
      refute RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: nil, recording: nil)
    end

    assert_nil seen[:actor]
    assert_nil seen[:recording]
  end

  def test_accessible_errors_are_not_rescued
    RecordingStudioAccessible.stub(:authorized?, ->(**) { raise "boom" }) do
      error = assert_raises(RuntimeError) do
        RecordingStudioOrderable::Authorization.authorized?(action: :reorder, actor: :user, recording: :rec)
      end
      assert_equal "boom", error.message
    end
  end
end
