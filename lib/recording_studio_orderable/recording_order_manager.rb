# frozen_string_literal: true

require "active_record"

module RecordingStudioOrderable
  class RecordingOrderManager
    class ConfigurationError < StandardError; end
    class DuplicateOrderError < StandardError; end

    class << self
      def recording_order_recordings(parent_recording, group_key = nil, owner: nil, named_only: false,
                                     orderable_name: nil)
        if named_only || orderable_name.to_s.strip.present?
          return named_order_recordings(
            parent_recording,
            group_key: group_key,
            owner: owner,
            orderable_name: orderable_name
          )
        end

        default_order_recordings(parent_recording, group_key: group_key, owner: owner)
      end

      def recording_orders(parent_recording, owner: nil, group: nil, orderable_name: nil, named_only: false)
        matching_order_recordings(
          parent_recording,
          owner: owner,
          group: group,
          orderable_name: orderable_name,
          named_only: named_only
        ).filter_map(&:recordable)
      end

      def recording_order_recording_for(parent_recording, group_key = nil, owner: nil)
        resolved_group_key = resolve_group_key!(parent_recording, group_key)
        matches = default_order_recordings(parent_recording, group_key: resolved_group_key, owner: owner)
        raise_duplicate_order!(parent_recording, resolved_group_key, owner, matches) if matches.many?

        matches.first
      end

      def default_recording_order(parent_recording, group_key = nil, owner: nil)
        recording_order_recording_for(parent_recording, group_key, owner: owner)&.recordable
      end

      def find_or_create_recording_order!(parent_recording, group_key = nil, owner: nil, actor: nil, metadata: {},
                                          name: nil, ordered_recording_ids: [])
        existing_order = default_recording_order(parent_recording, group_key, owner: owner)
        return existing_order if existing_order

        resolved_group_key = resolve_group_key!(parent_recording, group_key)
        owner_type, owner_id = owner_attributes(owner)
        order_record = RecordingStudio::RecordingStudioOrder.new(
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
      rescue ActiveRecord::RecordNotUnique
        recovered_order = default_recording_order(parent_recording, resolved_group_key, owner: owner)
        return recovered_order if recovered_order

        raise
      end

      def create_named_recording_order!(parent_recording, group_key = nil, name:, owner: nil, actor: nil,
                                        metadata: {}, source_order_recording_id: nil,
                                        ordered_recording_ids: nil)
        resolved_group_key = resolve_group_key!(parent_recording, group_key)
        owner_type, owner_id = owner_attributes(owner)
        requested_ids = if ordered_recording_ids.nil?
                          source_order_ids_for(
                            parent_recording,
                            resolved_group_key,
                            owner,
                            source_order_recording_id
                          ) || default_named_order_ids(parent_recording, resolved_group_key)
                        else
                          ordered_recording_ids
                        end

        order_record = RecordingStudio::RecordingStudioOrder.new(
          parent_recording_id: parent_recording.id,
          group_key: resolved_group_key,
          name: name,
          owner_type: owner_type,
          owner_id: owner_id,
          ordered_recording_ids: normalize_requested_ids(parent_recording, resolved_group_key, requested_ids)
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
        eligible_children = Array(parent_recording.child_recordings).select do |child_recording|
          allowed_types.include?(child_recording.recordable_type) &&
            child_recording.recordable_type != "RecordingStudio::RecordingStudioOrder"
        end

        eligible_children.sort_by { |child_recording| [child_recording.created_at, child_recording.id.to_s] }
      end

      def ordered_children_for(parent_recording, group_key = nil, owner: nil)
        resolved_group_key = resolve_group_key!(parent_recording, group_key)
        eligible_children = eligible_children_for(parent_recording, resolved_group_key)
        ordered_recording = default_recording_order(parent_recording, resolved_group_key, owner: owner)
        ordered_ids = Array(ordered_recording&.ordered_recording_ids)
        eligible_by_id = eligible_children.index_by { |child_recording| child_recording.id.to_s }

        explicitly_ordered_children = ordered_ids.filter_map { |recording_id| eligible_by_id.delete(recording_id.to_s) }
        explicitly_ordered_children + eligible_by_id.values
      end

      def normalize_requested_ids(parent_recording, group_key, requested_ids)
        eligible_ids = eligible_children_for(parent_recording, group_key).map(&:id).map(&:to_s)

        Array(requested_ids)
          .filter_map { |recording_id| normalize_recording_id(recording_id) }
          .uniq
          .select { |recording_id| eligible_ids.include?(recording_id) }
      end

      def matching_order_recordings(parent_recording, group_key: nil, owner: nil, group: nil, orderable_name: nil,
                                    named_only: false)
        resolved_group_key = resolve_group_filter_key!(parent_recording, group_key: group_key, group: group)
        resolved_orderable_name = normalize_orderable_name_filter(orderable_name)
        owner_type, owner_id = owner_attributes(owner)

        Array(parent_recording.child_recordings)
          .select { |child_recording| child_recording.recordable_type == "RecordingStudio::RecordingStudioOrder" }
          .select do |child_recording|
            order_record = child_recording.recordable
            next false unless order_record

            order_recording_matches_filters?(
              order_record,
              resolved_group_key: resolved_group_key,
              owner_type: owner_type,
              owner_id: owner_id,
              resolved_orderable_name: resolved_orderable_name,
              named_only: named_only
            )
          end
      end

      def default_order_recordings(parent_recording, group_key: nil, owner: nil)
        matching_order_recordings(parent_recording, group_key: group_key, owner: owner).select do |child_recording|
          order_name(child_recording.recordable).blank?
        end
      end

      def named_order_recordings(parent_recording, group_key: nil, owner: nil, orderable_name: nil)
        named_recordings = matching_order_recordings(
          parent_recording,
          group_key: group_key,
          owner: owner,
          orderable_name: orderable_name,
          named_only: true
        )

        named_recordings.sort_by { |child_recording| [child_recording.created_at, child_recording.id.to_s] }
      end

      def resolve_group_key!(parent_recording, group_key = nil)
        resolve_group_definition!(parent_recording, group_key).fetch(:group_key)
      end

      def resolve_group_filter_key!(parent_recording, group_key:, group:)
        normalized_group_key = group_key.to_s.presence
        normalized_group = group.to_s.presence

        return normalize_group_or_type_filter!(parent_recording, normalized_group) if normalized_group_key.nil?
        return resolve_group_key!(parent_recording, normalized_group_key) if normalized_group.nil?

        resolved_group_key = resolve_group_key!(parent_recording, normalized_group_key)
        resolved_group = normalize_group_or_type_filter!(parent_recording, normalized_group)

        return resolved_group_key if resolved_group_key == resolved_group

        raise ConfigurationError,
              "Conflicting group filters #{normalized_group_key.inspect} and #{normalized_group.inspect}"
      end

      def normalize_group_or_type_filter!(parent_recording, group_or_type)
        return if group_or_type.nil?

        begin
          return resolve_group_key!(parent_recording, group_or_type)
        rescue ConfigurationError, KeyError => e
          unresolved_group_error = e
        end

        recordable_class = parent_recording.recordable.class
        definitions = if recordable_class.respond_to?(:recording_studio_order_group_definitions)
                        recordable_class.recording_studio_order_group_definitions
                      else
                        {}
                      end

        matching_group_keys = matching_group_keys_for(definitions, group_or_type)

        return matching_group_keys.first if matching_group_keys.one?

        if matching_group_keys.many?
          raise ConfigurationError,
                "Ambiguous group filter #{group_or_type.inspect}. Matching groups: #{matching_group_keys.join(', ')}"
        end

        raise unresolved_group_error if definitions.empty?

        available_groups = definitions.keys.sort
        raise ConfigurationError,
              "Unknown group filter #{group_or_type.inspect}. Available groups: #{available_groups.join(', ')}"
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

      def default_named_order_ids(parent_recording, resolved_group_key)
        eligible_children_for(parent_recording, resolved_group_key)
          .reverse
          .map { |recording| recording.id.to_s }
      end

      def owner_attributes(owner)
        return [owner[:owner_type], normalize_recording_id(owner[:owner_id])] if owner.is_a?(Hash)
        return [owner[0], normalize_recording_id(owner[1])] if owner.is_a?(Array)
        return [nil, nil] if owner.nil?

        [owner.class.name, normalize_recording_id(owner)]
      end

      def source_order_ids_for(parent_recording, group_key, owner, source_order_recording_id)
        return if source_order_recording_id.blank?

        matching_order_recordings(parent_recording, group_key: group_key, owner: owner)
          .find { |recording| recording.id.to_s == source_order_recording_id.to_s }
          &.recordable
          &.ordered_recording_ids
      end

      def order_name(order_record)
        return unless order_record.respond_to?(:name)

        order_record.name.to_s.strip.presence
      end

      def normalize_orderable_name_filter(orderable_name)
        orderable_name.to_s.strip.presence
      end

      def order_recording_matches_filters?(order_record, resolved_group_key:, owner_type:, owner_id:,
                                           resolved_orderable_name:, named_only:)
        normalized_name = order_name(order_record)
        raw_name = raw_order_name(order_record)
        group_match = resolved_group_key.nil? || order_record.group_key == resolved_group_key
        owner_match = order_record.owner_type == owner_type && order_record.owner_id.to_s == owner_id.to_s
        name_match = resolved_orderable_name.nil? || normalized_name == resolved_orderable_name
        named_only_match = !named_only || named_order_value_present?(raw_name)

        group_match && owner_match && name_match && named_only_match
      end

      def named_order_value_present?(raw_name)
        !raw_name.nil? && raw_name != ""
      end

      def raw_order_name(order_record)
        return unless order_record.respond_to?(:name)

        order_record.name
      end

      def matching_group_keys_for(definitions, group_or_type)
        definitions
          .values
          .select { |definition| Array(definition[:allows]).include?(group_or_type) }
          .map { |definition| definition[:group_key] }
          .uniq
      end

      private

      def raise_duplicate_order!(parent_recording, group_key, owner, matches)
        owner_type, owner_id = owner_attributes(owner)
        raise DuplicateOrderError,
              "Multiple RecordingStudioOrder children exist for parent=#{parent_recording.id}, " \
              "group_key=#{group_key.inspect}, " \
              "owner_type=#{owner_type.inspect}, owner_id=#{owner_id.inspect} (#{matches.size} found)"
      end
    end
  end
end
