# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  config.authenticate_controller = lambda do |controller|
    controller.authenticate_user! if controller.respond_to?(:authenticate_user!, true)
  end

  config.current_owner_resolver = lambda do |_controller|
    RecordingStudio.configuration.actor&.call
  end

  config.authorize_parent_recording = lambda do |controller, parent_recording|
    controller.send(:current_user).present? && parent_recording.present?
  end
end