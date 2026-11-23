# frozen_string_literal: true

module RecordingStudioOrderable
  module McpCopy
    TOOLS = {
      "reorder_children" => {
        action: :reorder,
        title: "Reorder children",
        description: "Sets the sibling order of the direct children under this parent so they show in a " \
                     "chosen order. The parent type must opt in to ordering. Pass ordered_recording_ids " \
                     "as ids of direct children that parent allows. Listed children move to the front. " \
                     "Omitted eligible children are appended by created_at, then id. A missing, foreign, " \
                     "already-trashed, or duplicate id is rejected and the order stays as it was. An empty " \
                     "list orders every eligible child by created_at, then id. Children stay under this parent."
      }.freeze,
      "move_child_position" => {
        action: :move_position,
        title: "Move child position",
        description: "Moves one direct child to a new index under this same parent so that child sits at a " \
                     "chosen place. The parent type must opt in to ordering, and the child must be a direct " \
                     "child that parent allows. Pass recording_id as that child's id. Pass to_index as an " \
                     "index counting from 0. 0 is first. An index past the last child puts the child last. " \
                     "An index below 0 is treated as 0. A missing, foreign, or already-trashed id is rejected " \
                     "and the order stays as it was. An index that is not an integer is rejected. The child " \
                     "stays under this parent."
      }.freeze
    }.freeze

    SHARED_INPUT = {
      "type" => {
        description: "Public name of the parent type. That type must opt in to ordering."
      }.freeze,
      "id" => {
        description: "Recording id of the parent. Run this on the parent, not on a child."
      }.freeze
    }.freeze

    module_function

    def register!
      return unless defined?(::RecordingStudioMcp)
      return unless ::RecordingStudioMcp.respond_to?(:register_tool)

      registrations.each { |registration| ::RecordingStudioMcp.register_tool(**registration) }
    end

    def tool_names
      TOOLS.keys
    end

    def registrations
      TOOLS.map { |name, spec| registration_for(name, spec) }
    end

    def registration_for(name, spec)
      action = spec.fetch(:action)
      {
        name: name,
        action: action,
        title: spec.fetch(:title),
        description: spec.fetch(:description),
        input: input_for(action),
        output: success_for(action)
      }
    end

    def input_for(action)
      SHARED_INPUT.merge(field_inputs(action))
    end

    def field_inputs(action)
      fields = RecordingStudio::Orderable::Api::ACTIONS.fetch(action).fetch(:fields)
      fields.to_h { |field, spec| [field.to_s, { description: spec.fetch(:description) }] }
    end

    def success_for(action)
      RecordingStudio::Orderable::Api::ACTIONS.fetch(action).fetch(:success)
    end
    private_class_method :registration_for, :input_for, :field_inputs, :success_for
  end
end
