# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioOrderable::Configuration.new
  end

  def test_defaults_are_quiet
    assert_equal false, @configuration.log_order_events
    assert_equal "recording_order", @configuration.event_action_prefix
    assert_nil @configuration.authenticate_controller
    assert_nil @configuration.current_owner_resolver
  end

  def test_merge_updates_known_attributes
    authenticate_controller = ->(_controller) {}
    current_owner_resolver = ->(_controller) { :owner }

    @configuration.merge!(
      log_order_events: true,
      event_action_prefix: "ordering",
      authenticate_controller: authenticate_controller,
      current_owner_resolver: current_owner_resolver
    )

    assert_equal true, @configuration.log_order_events
    assert_equal "ordering", @configuration.event_action_prefix
    assert_same authenticate_controller, @configuration.authenticate_controller
    assert_same current_owner_resolver, @configuration.current_owner_resolver
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", log_order_events: true)

    refute_respond_to @configuration, :unknown_key
    assert_equal true, @configuration.log_order_events
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original, @configuration.to_h
  end

  def test_configure_without_block_is_safe
    RecordingStudioOrderable.configure

    assert_kind_of RecordingStudioOrderable::Configuration, RecordingStudioOrderable.configuration
  end
end
