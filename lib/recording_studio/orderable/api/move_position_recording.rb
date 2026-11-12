# frozen_string_literal: true

module RecordingStudio
  module Orderable
    module Api
      class MovePositionRecording
        def self.call(context)
          Errors.wrap do
            role = RecordingStudioOrderable.configuration.authorization_role
            context.access_grant.authorize!(recording: context.recording, role: role)
            context.recording.recording_studio_orderable_move!(
              context.params[:recording_id],
              to_index: context.params[:to_index],
              actor: context.actor
            )
            context.recording
          end
        end
      end
    end
  end
end
