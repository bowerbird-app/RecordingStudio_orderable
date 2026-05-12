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
        group_key = name.to_s
        allowed_types = Array(allows).map do |recordable_type|
          recordable_type.is_a?(Class) ? recordable_type.name : recordable_type.to_s
        end.uniq

        self.recording_studio_order_group_definitions = recording_studio_order_group_definitions.merge(
          group_key => { group_key: group_key, allows: allowed_types }
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

    def recording_orders(owner: nil)
      current_recording&.recording_orders(owner: owner) || []
    end

    def recording_order_for(group_key = nil, owner: nil)
      current_recording&.recording_order_for(group_key, owner: owner)
    end

    def find_or_create_recording_order!(group_key = nil, **)
      current_recording&.find_or_create_recording_order!(group_key, **)
    end

    def children_for_order_group(group_key = nil)
      current_recording&.children_for_order_group(group_key) || []
    end

    def ordered_children_for(group_key = nil, owner: nil)
      current_recording&.ordered_children_for(group_key, owner: owner) || []
    end

    private

    def current_recording
      matching_recordings = Array(recordings).compact
      return if matching_recordings.empty?

      matching_recordings.max_by do |recording|
        [
          recording.respond_to?(:updated_at) ? recording.updated_at : Time.at(0),
          recording.respond_to?(:created_at) ? recording.created_at : Time.at(0),
          recording.respond_to?(:id) ? recording.id.to_s : ""
        ]
      end
    end
  end
end
