# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  # Authorization is handled by RecordingStudioAccessible.
  config.log_order_events = true
end
