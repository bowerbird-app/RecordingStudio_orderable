# frozen_string_literal: true

module RecordingStudioOrderable
  class NotAuthorized < StandardError; end

  module Authorization
    module_function

    def authorized?(action:, actor:, recording:, controller: nil)
      resolver = RecordingStudioOrderable.configuration.authorization_resolver
      if resolver.respond_to?(:call)
        return resolver.call(action: action, actor: actor, recording: recording, controller: controller)
      end

      return true unless use_accessible?

      accessible_module.authorized?(
        actor: actor,
        recording: recording,
        role: RecordingStudioOrderable.configuration.authorization_role
      )
    end

    def use_accessible?
      RecordingStudioOrderable.configuration.use_recording_studio_accessible == true &&
        accessible_module.respond_to?(:authorized?)
    end

    def accessible_module
      configured = RecordingStudioOrderable.configuration.accessible_module
      return configured unless configured.nil?
      return RecordingStudioAccessible if defined?(RecordingStudioAccessible)

      nil
    end
  end
end
