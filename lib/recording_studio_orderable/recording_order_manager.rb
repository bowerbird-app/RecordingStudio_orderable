# frozen_string_literal: true

module RecordingStudioOrderable
  class RecordingOrderManager
    class ConfigurationError < StandardError; end
    class DuplicateOrderError < StandardError; end

    class << self
      def recording_order_recordings(parent_recording, group_key = nil, owner: nil)
        matching_order_recordings(parent_recording, group_key: group_key, owner: owner)
      end

      def recording_orders(parent_recording, owner: nil)
        matching_order_recordings(parent_recording, owner: owner).filter_map(&:recordable)
      end

      def recording_order_recording_for(parent_recording, group_key = nil, owner: nil)
        resolved_group_key = resolve_group_key!(parent_recording, group_key)
        matches = matching_order_recordings(parent_recording, group_key: resolved_group_key, owner: owner)
        raise_duplicate_order!(parent_recording, resolved_group_key, owner, matches) if matches.many?

        matches.first
      end

      def recording_order_for(parent_recording, group_key = nil, owner: nil)
        recording_order_recording_for(parent_recording, group_key, owner: owner)&.recordable
      end

      def find_or_create_recording_order!(parent_recording, group_key = nil, owner: nil, actor: nil, metadata: {},
                                          name: nil, ordered_recording_ids: [])
        existing_order = recording_order_for(parent_recording, group_key, owner: owner)
        return existing_order if existing_order

        resolved_group_key = resolve_group_key!(parent_recording, group_key)
        owner_type, owner_id = owner_attributes(owner)
        order_record = RecordingStudio::RecordingOrder.new(
          parent_recording_id: parent_recording.id,
          group_key: resolved_group_key,
          name: name,
          owner_type: owner_type,
          owner_id: owner_id,
          ordered_recording_ids: normalize_requested_ids(parent_recording, resolved_group_key, ordered_recording_ids)
        )
        order_record.parent_recording_for_validation = parent_recording
        order_record.recording_id_for_validation = nil

        parent_recording.record(
          order_record,
          actor: actor,
          metadata: metadata,
          parent_recording: parent_recording
        ).recordable
      end

      def eligible_children_for(parent_recording, group_key = nil)
        allowed_types = resolve_group_definition!(parent_recording, group_key).fetch(:allows)

        Array(parent_recording.child_recordings)
          .select do |child_recording|
            allowed_types.include?(child_recording.recordable_type) &&
              child_recording.recordable_type != "RecordingStudio::RecordingOrder"
          end
          .sort_by { |child_recording| [child_recording.created_at, child_recording.id.to_s] }
      end

      def ordered_children_for(parent_recording, group_key = nil, owner: nil)
        resolved_group_key = resolve_group_key!(parent_recording, group_key)
        eligible_children = eligible_children_for(parent_recording, resolved_group_key)
        ordered_ids = Array(recording_order_for(parent_recording, resolved_group_key, owner: owner)&.ordered_recording_ids)
        eligible_by_id = eligible_children.index_by { |child_recording| child_recording.id.to_s }

        explicitly_ordered_children = ordered_ids.filter_map { |recording_id| eligible_by_id.delete(recording_id.to_s) }
        explicitly_ordered_children + eligible_by_id.values
      end

      def normalize_requested_ids(parent_recording, group_key, requested_ids)
        eligible_ids = eligible_children_for(parent_recording, group_key).map { |child_recording| child_recording.id.to_s }

        Array(requested_ids)
          .filter_map { |recording_id| normalize_recording_id(recording_id) }
          .uniq
          .select { |recording_id| eligible_ids.include?(recording_id) }
      end

      def matching_order_recordings(parent_recording, group_key: nil, owner: nil)
        resolved_group_key = group_key && resolve_group_key!(parent_recording, group_key)
        owner_type, owner_id = owner_attributes(owner)

        Array(parent_recording.child_recordings)
          .select { |child_recording| child_recording.recordable_type == "RecordingStudio::RecordingOrder" }
          .select do |child_recording|
            order_record = child_recording.recordable
            next false unless order_record

            group_match = resolved_group_key.nil? || order_record.group_key == resolved_group_key
            owner_match = order_record.owner_type == owner_type && order_record.owner_id.to_s == owner_id.to_s
            group_match && owner_match
          end
      end

      def resolve_group_key!(parent_recording, group_key = nil)
        resolve_group_definition!(parent_recording, group_key).fetch(:group_key)
      end

      def resolve_group_definition!(parent_recording, group_key = nil)
        recordable_class = parent_recording.recordable.class

        unless recordable_class.respond_to?(:recording_studio_order_group_definition)
          raise ConfigurationError, "#{recordable_class.name} does not define any recording_studio_order_group entries"
        end

        recordable_class.recording_studio_order_group_definition(group_key)
      end

      def normalize_recording_id(recording_id)
        value = if recording_id.respond_to?(:id) && !recording_id.is_a?(String)
                  recording_id.id
                else
                  recording_id
                end

        value.to_s.presence
      end

      def owner_attributes(owner)
        return [owner[:owner_type], normalize_recording_id(owner[:owner_id])] if owner.is_a?(Hash)
        return [owner[0], normalize_recording_id(owner[1])] if owner.is_a?(Array)
        return [nil, nil] if owner.nil?

        [owner.class.name, normalize_recording_id(owner)]
      end

      private

      def raise_duplicate_order!(parent_recording, group_key, owner, matches)
        owner_type, owner_id = owner_attributes(owner)
        raise DuplicateOrderError,
              "Multiple RecordingOrder children exist for parent=#{parent_recording.id}, group_key=#{group_key.inspect}, " \
              "owner_type=#{owner_type.inspect}, owner_id=#{owner_id.inspect} (#{matches.size} found)"
      end
    end
  end
end
