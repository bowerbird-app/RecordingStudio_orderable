# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  # Optional additional host auth check after Recording Studio actor authentication passes.
  # If omitted, mounted UI authentication relies on RecordingStudio.configuration.actor.
  config.authenticate_controller = lambda do |controller|
    controller.authenticate_user! if controller.respond_to?(:authenticate_user!, true)
  end

  # Resolve owner scope through RecordingStudio actor config (typically Current.actor).
  config.current_owner_resolver = lambda do |_controller|
    RecordingStudio.configuration.actor&.call
  end

  # Authorize the resolved parent recording before the mounted list UI can read or mutate it.
  config.authorize_parent_recording = lambda do |controller, parent_recording|
    controller.send(:current_user).present? && parent_recording.present?
  end

  # Optional semantic event logging for order mutations.
  # Recording Studio creation/update events still happen as normal.
  config.log_order_events = false

  # Event names become "#{config.event_action_prefix}_reordered", etc.
  config.event_action_prefix = "recording_order"
end
