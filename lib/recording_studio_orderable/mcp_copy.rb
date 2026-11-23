# frozen_string_literal: true

require_relative "mcp_copy/copy"

module RecordingStudioOrderable
  module McpCopy
    VERBS = {
      "order" => :reorder,
      "move" => :move_position
    }.freeze

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
        description: action == :reorder ? Copy::REORDER : Copy::MOVE,
        input: input_for(action),
        output: Copy::OUTPUTS.fetch(action)
      }
    end

    def title_for(verb, noun)
      label = noun.tr("_", " ")
      verb == "order" ? "Order #{label}" : "Move #{label}"
    end

    def input_for(action)
      { "id" => Copy::ID_INPUT }.merge(field_inputs(action))
    end

    def field_inputs(action)
      fields = RecordingStudio::Orderable::Api::ACTIONS.fetch(action).fetch(:fields)
      copy = Copy::FIELD_COPY.fetch(action)
      fields.to_h { |field, _spec| [field.to_s, { description: copy.fetch(field.to_s) }] }
    end
    private_class_method :orderable_parents, :noun_by_parent, :proposed_noun, :disambiguated_noun,
                         :allowed_type_names, :public_token, :api_public_name, :tools_for, :tool_for,
                         :title_for, :input_for, :field_inputs
  end
end
