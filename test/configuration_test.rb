# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioOrderable::Configuration.new
  end

  def test_defaults_log_reorder_events
    assert_equal true, @configuration.log_order_events
    assert_equal "reordered", @configuration.event_action
    assert_equal true, @configuration.use_recording_studio_accessible
    assert_equal :edit, @configuration.authorization_role
    assert_nil @configuration.authorization_resolver
  end

  def test_merge_updates_known_attributes
    resolver = ->(*) { true }
    @configuration.merge!(
      log_order_events: false,
      event_action: "pages_reordered",
      authorization_resolver: resolver,
      use_recording_studio_accessible: false,
      authorization_role: :admin
    )

    assert_equal false, @configuration.log_order_events
    assert_equal "pages_reordered", @configuration.event_action
    assert_equal resolver, @configuration.authorization_resolver
    assert_equal false, @configuration.use_recording_studio_accessible
    assert_equal :admin, @configuration.authorization_role
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", log_order_events: false)

    refute_respond_to @configuration, :unknown_key
    assert_equal false, @configuration.log_order_events
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
