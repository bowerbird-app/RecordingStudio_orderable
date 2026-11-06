# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < Minitest::Test
  ACTIONS = %i[reorder move append].freeze

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

  def test_uses_non_default_authorization_role
    seen = nil
    RecordingStudioOrderable.configuration.authorization_role = :admin

    RecordingStudioAccessible.stub(:authorized?, lambda { |**kwargs|
      seen = kwargs
      kwargs[:role] == :edit
    }) do
      ACTIONS.each do |action|
        refute RecordingStudioOrderable::Authorization.authorized?(
          action: action,
          actor: :user,
          recording: :rec
        )
      end
    end

    assert_equal :admin, seen[:role]
  end

  ACTIONS.each do |action|
    define_method("test_denies_#{action}_when_accessible_returns_false") do
      refute_authorized(action, accessible: false)
    end

    define_method("test_denies_#{action}_when_accessible_returns_nil") do
      refute_authorized(action, accessible: nil)
    end

    define_method("test_passes_blank_actor_through_to_accessible_for_#{action}") do
      assert_blank_actor_passed_through(action)
    end

    define_method("test_#{action}_does_not_rescue_accessible_errors") do
      assert_accessible_error_propagates(action)
    end
  end

  private

  def refute_authorized(action, accessible:)
    RecordingStudioAccessible.stub(:authorized?, accessible) do
      refute RecordingStudioOrderable::Authorization.authorized?(action: action, actor: :user, recording: :rec)
    end
  end

  def assert_blank_actor_passed_through(action)
    seen = nil
    RecordingStudioAccessible.stub(:authorized?, lambda { |**kwargs|
      seen = kwargs
      false
    }) do
      refute RecordingStudioOrderable::Authorization.authorized?(action: action, actor: nil, recording: nil)
    end

    assert_nil seen[:actor]
    assert_nil seen[:recording]
  end

  def assert_accessible_error_propagates(action)
    RecordingStudioAccessible.stub(:authorized?, ->(**) { raise "boom" }) do
      error = assert_raises(RuntimeError) do
        RecordingStudioOrderable::Authorization.authorized?(action: action, actor: :user, recording: :rec)
      end
      assert_equal "boom", error.message
    end
  end
end
