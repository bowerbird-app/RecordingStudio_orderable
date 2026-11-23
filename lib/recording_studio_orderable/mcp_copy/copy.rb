# frozen_string_literal: true

module RecordingStudioOrderable
  module McpCopy
    module Copy
      ID_INPUT = {
        description: "Recording id of this parent."
      }.freeze

      OUTPUTS = {
        reorder: "The children are in the new order.",
        move_position: "The child is at the new index."
      }.freeze

      FIELD_COPY = {
        reorder: {
          "ordered_recording_ids" => "Ids of the direct children in the new order. Listed children move to the " \
                                     "front. Omitted eligible children are appended by created_at, then id. " \
                                     "A missing, foreign, already-trashed, or duplicate id is rejected and the " \
                                     "order stays as it was."
        }.freeze,
        move_position: {
          "recording_id" => "Id of the direct child to move. A missing, foreign, or already-trashed id is rejected.",
          "to_index" => "Index among eligible children, counting from 0. 0 is first. An index past the last " \
                        "child puts the child last. An index below 0 is treated as 0."
        }.freeze
      }.freeze

      REORDER = "Sets the sibling order of the direct children under this parent so they show in a " \
                "chosen order. Pass ordered_recording_ids as ids of direct children this parent allows. " \
                "Listed children move to the front. Omitted eligible children are appended by created_at, " \
                "then id. A missing, foreign, already-trashed, or duplicate id is rejected and the order " \
                "stays as it was. An empty list orders every eligible child by created_at, then id. " \
                "Children stay under this parent."

      MOVE = "Moves one direct child to a new index under this same parent so that child sits at a " \
             "chosen place. The child must be a direct child this parent allows. Pass recording_id as " \
             "that child's id. Pass to_index as an index counting from 0. 0 is first. An index past the " \
             "last child puts the child last. An index below 0 is treated as 0. A missing, foreign, or " \
             "already-trashed id is rejected and the order stays as it was. An index that is not an " \
             "integer is rejected. The child stays under this parent."
    end
  end
end
