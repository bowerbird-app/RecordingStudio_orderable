# frozen_string_literal: true

module RecordingStudioOrderable
  class NotAuthorized < StandardError; end

  module Authorization
    module_function

    def authorized?(actor:, recording:, **)
      return false unless defined?(RecordingStudioAccessible)
      return false unless RecordingStudioAccessible.respond_to?(:authorized?)

      !!RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: recording,
        role: RecordingStudioOrderable.configuration.authorization_role
      )
    end
  end
end
