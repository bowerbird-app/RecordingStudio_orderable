# frozen_string_literal: true

module RecordingStudio
  module Orderable
    module Api
      class ReorderRecording
        def self.call(context)
          Errors.wrap do
            role = RecordingStudioOrderable.configuration.authorization_role
            context.access_grant.authorize!(recording: context.recording, role: role)
            context.recording.recording_studio_orderable_reorder!(
              ordered_recording_ids: context.params[:ordered_recording_ids],
              actor: context.actor
            )
            context.recording
          end
        end
      end
    end
  end
end
