# frozen_string_literal: true

require "recording_studio/orderable/api/errors"
require "recording_studio/orderable/api/move_position_recording"
require "recording_studio/orderable/api/reorder_recording"
require "recording_studio/orderable/api/openapi_overrides"
require "recording_studio/orderable/api/registration"
require "recording_studio_orderable/mcp_copy"

module RecordingStudio
  module Orderable
    module Api
      ACTION_VERSION = "1.0.0"
      ACTIONS = {
        reorder: {
          handler: ReorderRecording,
          summary: "Reorder the direct children of this recording.",
          description: "POST sets the sibling order of the direct children of the recording in the URL. " \
                       "The body field ordered_recording_ids lists child recording ids in the new order. " \
                       "Listed children move to the front. Eligible children omitted from the list are appended " \
                       "by created_at, then id. An empty list orders every eligible child by created_at, then id. " \
                       "A missing, foreign, already-trashed, or duplicate id raises InvalidChild and positions " \
                       "stay unchanged. The response is this recording. Create and update do not set position.",
          success: "This recording is returned with its children in the new order.",
          forbidden: "The caller cannot reorder the children of this recording.",
          invalid: "The reorder body is invalid.",
          fields: {
            ordered_recording_ids: {
              type: :array,
              required: true,
              description: "Child recording ids in the requested order. Listed ids come first. Eligible children " \
                           "omitted from the array are appended by created_at, then id. An empty array orders " \
                           "every eligible child by created_at, then id. A missing, foreign, already-trashed, or " \
                           "duplicate id raises InvalidChild and positions stay unchanged."
            }
          }
        }.freeze,
        move_position: {
          handler: MovePositionRecording,
          summary: "Move one direct child to a new index.",
          description: "POST moves one direct child to a sibling index under the recording in the URL. " \
                       "The child stays under this parent. The body field recording_id is the child recording id. " \
                       "The body field to_index is the index among eligible children, counting from 0. " \
                       "0 is first. An index below 0 is treated as 0. An index past the last child puts the child " \
                       "last. A missing, foreign, or already-trashed recording_id raises InvalidChild and positions " \
                       "stay unchanged. A to_index that is not an integer is rejected and positions stay unchanged. " \
                       "The response is this recording. Create and update do not set position.",
          success: "This recording is returned with the child at the requested index.",
          forbidden: "The caller cannot move a child of this recording.",
          invalid: "The move body is invalid.",
          fields: {
            recording_id: {
              type: :string,
              required: true,
              allow_blank: false,
              description: "Id of the direct child to move. A missing, foreign, or already-trashed id raises " \
                           "InvalidChild and positions stay unchanged."
            },
            to_index: {
              type: :integer,
              required: true,
              description: "Index among eligible children, counting from 0. 0 is first. A value below 0 is " \
                           "treated as 0. A value past the last child puts the child last. A non-integer is rejected."
            }
          }
        }.freeze
      }.freeze

      def self.override_openapi(type:, action:, title:, description:)
        OpenapiOverrides.store(type: type, action: action, title: title, description: description)
      end

      def self.openapi_for(action:, type: nil)
        OpenapiOverrides.document(action, type: type)
      end

      def self.register_capability_action!
        registered = Registration.register!
        RecordingStudioOrderable::McpCopy.register!
        registered
      end
    end
  end
end
