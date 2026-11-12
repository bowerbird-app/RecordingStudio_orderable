# frozen_string_literal: true

require "recording_studio/orderable/api/errors"
require "recording_studio/orderable/api/move_position_recording"
require "recording_studio/orderable/api/reorder_recording"
require "recording_studio/orderable/api/registration"

module RecordingStudio
  module Orderable
    module Api
      ACTION_VERSION = "1.0.0"
      ACTIONS = {
        reorder: {
          handler: ReorderRecording,
          summary: "Recording - Reorder",
          description: "Set the sibling order of children under this recording. " \
                       "Position is not written through create or update.",
          success: "Children reordered.",
          forbidden: "API access is not authorized to reorder this recording.",
          invalid: "Reorder request is invalid.",
          fields: {
            ordered_recording_ids: {
              type: :array,
              required: true,
              description: "Child recording ids in the new sibling order."
            }
          }
        }.freeze,
        move_position: {
          handler: MovePositionRecording,
          summary: "Recording - Move position",
          description: "Move one child to a sibling index under this recording. " \
                       "This does not change parent. Do not use Moveable.",
          success: "Child moved in sibling order.",
          forbidden: "API access is not authorized to move this recording.",
          invalid: "Move request is invalid.",
          fields: {
            recording_id: {
              type: :string,
              required: true,
              allow_blank: false,
              description: "Id of the child recording to move."
            },
            to_index: {
              type: :integer,
              required: true,
              description: "Zero-based sibling index to insert the child at."
            }
          }
        }.freeze
      }.freeze

      def self.register_capability_action!
        Registration.register!
      end
    end
  end
end
