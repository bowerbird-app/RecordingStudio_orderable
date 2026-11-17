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
          summary: "Change the order of the children under this recording.",
          description: "Sets the sibling order of children under this recording. Run this on the parent recording, " \
                       "not on a child. Create this recording first, then create the children under it. Pass " \
                       "ordered_recording_ids as those children's ids from this recording's children list, or the " \
                       "ids returned when they were created. Do not pass this recording's own id. A partial list is " \
                       "allowed: listed children move to the front, and omitted eligible children are appended by " \
                       "created_at then id. Any missing, foreign, already-trashed, or duplicate id is rejected, and " \
                       "nothing is changed. An empty list is allowed: eligible children are then ordered by " \
                       "created_at then id. Position is not set through create or update. If the children are " \
                       "already in that order, the call succeeds and the order stays the same. Returns this recording.",
          success: "Children reordered.",
          forbidden: "API access is not authorized to reorder this recording.",
          invalid: "Reorder request is invalid.",
          fields: {
            ordered_recording_ids: {
              type: :array,
              required: true,
              description: "The child recording ids in the new sibling order. These are the children's ids from this " \
                           "recording's children list, or the ids returned when they were created, not this " \
                           "recording's own id. A partial list is allowed: listed children move to the front, and " \
                           "omitted eligible children are appended by created_at then id. Any missing, foreign, " \
                           "already-trashed, or duplicate id is rejected, and nothing is changed. An empty list is " \
                           "allowed."
            }
          }
        }.freeze,
        move_position: {
          handler: MovePositionRecording,
          summary: "Move one child to a new place among this recording's children.",
          description: "Moves one child to a sibling index under this recording. The child stays under this " \
                       "recording. This does not change parent. To change parent, use the gem that moves recordings. " \
                       "Run this on the parent recording, not on the child. Create this recording first, then create " \
                       "the child under it. Pass recording_id as that child's id from this recording's children " \
                       "list, or the id returned when it was created. Pass to_index as a zero-based sibling index " \
                       "among eligible children (0 is first). A missing, foreign, or already-trashed recording_id is " \
                       "rejected, and nothing is changed. A to_index that is not an integer is rejected, and nothing " \
                       "is changed. A to_index below 0 is treated as 0. A to_index past the last sibling puts the " \
                       "child last. Position is not set through create or update. If the child is already at that " \
                       "index, the call succeeds and the order stays the same. Returns this recording.",
          success: "Child moved in sibling order.",
          forbidden: "API access is not authorized to move this recording.",
          invalid: "Move request is invalid.",
          fields: {
            recording_id: {
              type: :string,
              required: true,
              allow_blank: false,
              description: "The id of the child recording to move. Use the id from this recording's children list, " \
                           "or the id returned when the child was created. Not this recording's own id. A missing, " \
                           "foreign, or already-trashed id is rejected."
            },
            to_index: {
              type: :integer,
              required: true,
              description: "Where the child should sit among this recording's eligible children, counting from 0. " \
                           "0 is first. A number past the last sibling puts it last. A number below 0 is treated as " \
                           "0. Must be an integer."
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
