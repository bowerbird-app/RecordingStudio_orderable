# frozen_string_literal: true

module RecordingStudioOrderable
  module OrderableRecordable
    extend ActiveSupport::Concern

    included do
      has_many :recordings, as: :recordable, class_name: "RecordingStudio::Recording", inverse_of: :recordable
      class_attribute :recording_studio_order_group_definitions, instance_writer: false, default: {}
    end

    class_methods do
      def recording_studio_order_group(name, allows:)
        group_name = name.to_s
        allowed_types = Array(allows).map { |recordable_type| recordable_type.is_a?(Class) ? recordable_type.name : recordable_type.to_s }.uniq

        self.recording_studio_order_group_definitions = recording_studio_order_group_definitions.merge(
          group_name => {name: group_name, allows: allowed_types}
        )
      end

      def recording_studio_order_group_definition(name = nil)
        definitions = recording_studio_order_group_definitions
        key = name.to_s.presence || default_recording_studio_order_group
        definition = definitions[key]

        return definition if definition

        available = definitions.keys
        raise RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
              "Unknown order group #{key.inspect}. Available groups: #{available.join(', ')}"
      end

      def default_recording_studio_order_group
        keys = recording_studio_order_group_definitions.keys
        return keys.first if keys.one?

        raise RecordingStudioOrderable::RecordingOrderManager::ConfigurationError,
              "A group name is required when #{name} defines multiple recording_studio_order_group entries"
      end
    end

    def recording_orders
      current_recording&.recording_orders || []
    end

    def recording_order_for(group_name = nil)
      current_recording&.recording_order_for(group_name)
    end

    def find_or_create_recording_order!(group_name = nil, **options)
      current_recording&.find_or_create_recording_order!(group_name, **options)
    end

    def children_for_order_group(group_name = nil)
      current_recording&.children_for_order_group(group_name) || []
    end

    def ordered_children_for(group_name = nil)
      current_recording&.ordered_children_for(group_name) || []
    end

    private

    def current_recording
      Array(recordings).max_by { |recording| [recording.updated_at, recording.id.to_s] }
    end
  end
end
