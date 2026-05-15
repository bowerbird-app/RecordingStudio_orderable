# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  # Protect the mounted UI with your host app's authentication flow.
  config.authenticate_controller = lambda do |controller|
    controller.authenticate_user! if controller.respond_to?(:authenticate_user!, true)
  end

  # Resolve the owner scope used for named lists and owner-scoped default orders.
  config.current_owner_resolver = lambda do |controller|
    controller.send(:current_user) if controller.respond_to?(:current_user, true)
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
