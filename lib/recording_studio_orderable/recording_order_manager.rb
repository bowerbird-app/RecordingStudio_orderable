# frozen_string_literal: true

module RecordingStudioOrderable
  class RecordingOrderManager
    class ConfigurationError < StandardError; end

    class << self
      def recording_order_recordings(parent_recording)
        Array(parent_recording.child_recordings).select do |child_recording|
          child_recording.recordable_type == "RecordingStudio::RecordingOrder"
        end
      end

      def recording_orders(parent_recording)
        recording_order_recordings(parent_recording).filter_map(&:recordable)
      end

      def recording_order_recording_for(parent_recording, group_name = nil)
        resolved_group = resolve_group!(parent_recording, group_name)

        recording_order_recordings(parent_recording).find do |child_recording|
          child_recording.recordable&.order_group == resolved_group
        end
      end

      def recording_order_for(parent_recording, group_name = nil)
        recording_order_recording_for(parent_recording, group_name)&.recordable
      end

      def find_or_create_recording_order!(parent_recording, group_name = nil, actor: nil, metadata: {}, ordered_recording_ids: [])
        existing_order = recording_order_for(parent_recording, group_name)
        return existing_order if existing_order

        resolved_group = resolve_group!(parent_recording, group_name)
        order_record = RecordingStudio::RecordingOrder.new(
          parent_recording_id: parent_recording.id,
          order_group: resolved_group,
          ordered_recording_ids: normalize_requested_ids(parent_recording, resolved_group, ordered_recording_ids)
        )
        order_record.parent_recording_for_validation = parent_recording

        parent_recording.record(
          order_record,
          actor: actor,
          metadata: metadata,
          parent_recording: parent_recording
        ).recordable
      end

      def eligible_children_for(parent_recording, group_name = nil)
        allowed_types = resolve_group_definition!(parent_recording, group_name).fetch(:allows)

        Array(parent_recording.child_recordings)
          .select { |child_recording| allowed_types.include?(child_recording.recordable_type) }
          .sort_by { |child_recording| [child_recording.created_at, child_recording.id.to_s] }
      end

      def ordered_children_for(parent_recording, group_name = nil)
        resolved_group = resolve_group!(parent_recording, group_name)
        eligible_children = eligible_children_for(parent_recording, resolved_group)
        ordered_ids = Array(recording_order_for(parent_recording, resolved_group)&.ordered_recording_ids)
        eligible_by_id = eligible_children.index_by { |child_recording| child_recording.id.to_s }

        explicitly_ordered_children = ordered_ids.filter_map { |recording_id| eligible_by_id.delete(recording_id.to_s) }
        explicitly_ordered_children + eligible_by_id.values
      end

      def normalize_requested_ids(parent_recording, group_name, requested_ids)
        eligible_ids = eligible_children_for(parent_recording, group_name).map { |child_recording| child_recording.id.to_s }

        Array(requested_ids)
          .filter_map { |recording_id| normalize_recording_id(recording_id) }
          .uniq
          .select { |recording_id| eligible_ids.include?(recording_id) }
      end

      def resolve_group!(parent_recording, group_name = nil)
        resolve_group_definition!(parent_recording, group_name).fetch(:name)
      end

      def resolve_group_definition!(parent_recording, group_name = nil)
        recordable_class = parent_recording.recordable.class

        unless recordable_class.respond_to?(:recording_studio_order_group_definition)
          raise ConfigurationError, "#{recordable_class.name} does not define any recording_studio_order_group entries"
        end

        recordable_class.recording_studio_order_group_definition(group_name)
      end

      def normalize_recording_id(recording_id)
        value = if recording_id.respond_to?(:id) && !recording_id.is_a?(String)
                  recording_id.id
                else
                  recording_id
                end

        value.to_s.presence
      end
    end
  end
end
