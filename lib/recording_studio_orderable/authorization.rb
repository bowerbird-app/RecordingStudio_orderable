# frozen_string_literal: true

module RecordingStudioOrderable
  module Authorization
    module_function

    def authorized?(action:, actor:, recording:, controller: nil)
      resolver = RecordingStudioOrderable.configuration.authorization_resolver
      if resolver.respond_to?(:call)
        return resolver.call(action: action, actor: actor, recording: recording, controller: controller)
      end

      return accessible_authorized?(actor: actor, recording: recording) if use_accessible?

      true
    end

    def use_accessible?
      RecordingStudioOrderable.configuration.use_recording_studio_accessible == true &&
        defined?(RecordingStudioAccessible) &&
        RecordingStudioAccessible.respond_to?(:authorized?)
    end

    def accessible_authorized?(actor:, recording:)
      return false if actor.blank? || recording.blank?

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: recording,
        role: RecordingStudioOrderable.configuration.authorization_role
      )
    rescue StandardError
      false
    end
  end
end
