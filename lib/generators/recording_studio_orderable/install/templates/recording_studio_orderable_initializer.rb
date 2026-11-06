# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  # Reorder history is written with RecordingStudio::Recording#log_event!.
  config.log_order_events = true
  config.event_action = "reordered"

  # Reorder, move, and append call RecordingStudioAccessible.authorized?
  # with this role on the parent recording. Missing Accessible denies.
  config.authorization_role = :edit
end
