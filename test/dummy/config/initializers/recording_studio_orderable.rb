# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  config.authenticate_controller = lambda do |controller|
    controller.authenticate_user! if controller.respond_to?(:authenticate_user!, true)
  end

  config.current_owner_resolver = lambda do |controller|
    controller.send(:current_user) if controller.respond_to?(:current_user, true)
  end
end