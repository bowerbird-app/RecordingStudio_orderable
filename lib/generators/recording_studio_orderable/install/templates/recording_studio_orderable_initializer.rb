# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  # Reorder history is written with RecordingStudio::Recording#log_event!.
  config.log_order_events = true
  config.event_action = "reordered"

  # When RecordingStudioAccessible is loaded, reorder calls check this role.
  # Set to false if the host app authorizes reorder itself.
  config.use_recording_studio_accessible = true
  config.authorization_role = :edit

  # Optional explicit authorizer. When set, Accessible is not consulted.
  # config.authorization_resolver = ->(action:, actor:, recording:, **) { actor.present? }
end
