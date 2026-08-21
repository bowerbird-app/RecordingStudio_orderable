# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  config.log_order_events = true
  config.event_action = "reordered"
  config.use_recording_studio_accessible = false
  config.authorization_resolver = ->(action:, actor:, **) { action.present? && actor.present? }
end
