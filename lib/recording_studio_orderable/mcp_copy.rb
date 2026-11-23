# frozen_string_literal: true

module RecordingStudioOrderable
  module McpCopy
    VERBS = {
      "order" => :reorder,
      "move" => :move_position
    }.freeze

    ID_INPUT = {
      description: "Recording id of this parent."
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

    module_function

    def register!
      return unless defined?(::RecordingStudioMcp)
      return unless ::RecordingStudioMcp.respond_to?(:register_tool)

      registrations.each { |registration| ::RecordingStudioMcp.register_tool(**registration) }
    end

    def tool_names
      registrations.map { |tool| tool.fetch(:name) }
    end

    def registrations
      nouns = noun_by_parent
      orderable_parents.flat_map { |parent| tools_for(parent, nouns.fetch(parent)) }
    end

    def orderable_parents
      RecordingStudio.configuration.enabled_recordable_types_for(:orderable)
    end

    def noun_by_parent
      parents = orderable_parents
      proposed = parents.to_h { |parent| [parent, proposed_noun(parent)] }
      counts = proposed.values.tally
      proposed.to_h { |parent, noun| [parent, disambiguated_noun(parent, noun, counts)] }
    end

    def proposed_noun(parent)
      allows = allowed_type_names(parent)
      public_token(allows.one? ? allows.first : parent)
    end

    def disambiguated_noun(parent, noun, counts)
      return noun unless counts[noun] > 1 && noun != public_token(parent)

      "#{public_token(parent)}_#{noun}"
    end

    def allowed_type_names(parent)
      Array(RecordingStudioOrderable.capability_options_for(parent)[:allows]).map(&:to_s).reject(&:blank?)
    end

    def public_token(type_name)
      token = api_public_name(type_name).to_s.strip
      token = type_name.to_s if token.empty?
      snake = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(token)).tr(" ", "_")
      snake.end_with?("s") ? ActiveSupport::Inflector.singularize(snake) : snake
    end

    def api_public_name(type_name)
      return unless defined?(::RecordingStudioApi)
      return unless ::RecordingStudioApi.respond_to?(:recordable_registration_for)

      ::RecordingStudioApi.recordable_registration_for(type_name, api: :public)&.public_name
    end

    def tools_for(parent, noun)
      VERBS.map { |verb, action| tool_for(parent, noun, verb, action) }
    end

    def tool_for(parent, noun, verb, action)
      {
        name: "#{verb}_#{noun}",
        type: parent,
        action: action,
        title: title_for(verb, noun),
        description: action == :reorder ? REORDER : MOVE,
        input: input_for(action),
        output: RecordingStudio::Orderable::Api::ACTIONS.fetch(action).fetch(:success)
      }
    end

    def title_for(verb, noun)
      label = noun.tr("_", " ")
      verb == "order" ? "Order #{label}" : "Move #{label}"
    end

    def input_for(action)
      { "id" => ID_INPUT }.merge(field_inputs(action))
    end

    def field_inputs(action)
      fields = RecordingStudio::Orderable::Api::ACTIONS.fetch(action).fetch(:fields)
      fields.to_h { |field, spec| [field.to_s, { description: spec.fetch(:description) }] }
    end
    private_class_method :orderable_parents, :noun_by_parent, :proposed_noun, :disambiguated_noun,
                         :allowed_type_names, :public_token, :api_public_name, :tools_for, :tool_for,
                         :title_for, :input_for, :field_inputs
  end
end
