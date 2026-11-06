# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  config.log_order_events = true
  config.event_action = "reordered"
  config.authorization_role = :edit
end
