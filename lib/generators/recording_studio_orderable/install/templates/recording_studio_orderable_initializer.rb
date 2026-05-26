# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  # Authorization is handled by RecordingStudioAccessible.

  # Optional semantic event logging for order mutations.
  # Recording Studio creation/update events still happen as normal.
  config.log_order_events = false

  # Event names become "#{config.event_action_prefix}_reordered", etc.
  config.event_action_prefix = "recording_order"
end
