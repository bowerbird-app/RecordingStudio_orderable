# frozen_string_literal: true

module RecordingStudio
  class RecordingStudioOrder < ActiveRecord::Base
    UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    attr_accessor :parent_recording_for_validation, :recording_id_for_validation

    has_many :recordings, as: :recordable, class_name: "RecordingStudio::Recording", inverse_of: :recordable

    validates :parent_recording_id, :group_key, presence: true
    validate :group_key_must_be_supported
    validate :order_scope_must_be_unique
    validate :ordered_recording_ids_must_be_unique
    validate :ordered_recording_ids_must_be_uuids
    validate :ordered_recording_ids_must_belong_to_eligible_items, if: -> { resolved_parent_recording.present? }

    before_validation :normalize_name
    before_validation :normalize_ordered_recording_ids

    alias_attribute :order_group, :group_key

    def eligible_items
      resolved_parent_recording&.eligible_order_items(group_key) || []
    end

    def ordered_item_recordings(owner: resolved_owner)
      parent_recording = resolved_parent_recording
      return [] unless parent_recording

      if current_attached_order_recording(self)
        ordered_items_for_current_order(parent_recording)
      else
        parent_recording.ordered_items_for(group_key, owner: owner) || []
      end
    end

    def include_item!(child_recording, actor: nil, metadata: {})
      updated_ids = normalized_mutation_ids
      child_recording_id = normalize_recording_id(child_recording)
      updated_ids.delete(child_recording_id)
      updated_ids << child_recording_id

      persist_updated_ids!(updated_ids, actor: actor, metadata: metadata, action: "included")
    end

    def remove_item!(child_recording, actor: nil, metadata: {})
      updated_ids = normalized_mutation_ids - [normalize_recording_id(child_recording)]
      persist_updated_ids!(updated_ids, actor: actor, metadata: metadata, action: "removed")
    end

    def move_before!(moving:, before:, actor: nil, metadata: {})
      move_relative!(moving: moving, anchor: before, placement: :before, actor: actor, metadata: metadata)
    end

    def move_after!(moving:, after:, actor: nil, metadata: {})
      move_relative!(moving: moving, anchor: after, placement: :after, actor: actor, metadata: metadata)
    end

    def move_to_start!(moving:, actor: nil, metadata: {})
      updated_ids = resolved_mutation_ids
      moving_id = normalize_recording_id(moving)
      updated_ids.delete(moving_id)
      updated_ids.unshift(moving_id)

      persist_updated_ids!(updated_ids, actor: actor, metadata: metadata, action: "moved")
    end

    def move_to_end!(moving:, actor: nil, metadata: {})
      updated_ids = resolved_mutation_ids.tap do |ids|
        moving_id = normalize_recording_id(moving)
        ids.delete(moving_id)
        ids << moving_id
      end

      persist_updated_ids!(updated_ids, actor: actor, metadata: metadata, action: "moved")
    end

    def move_to_position!(moving:, position:, actor: nil, metadata: {})
      updated_ids = resolved_mutation_ids
      moving_id = normalize_recording_id(moving)
      return self if moving_id.blank?

      insert_index = Integer(position)
      updated_ids.delete(moving_id)
      updated_ids.insert(insert_index.clamp(0, updated_ids.length), moving_id)

      persist_updated_ids!(updated_ids, actor: actor, metadata: metadata, action: "moved")
    rescue ArgumentError, TypeError
      self
    end

    def reorder!(ordered_recording_ids:, actor: nil, metadata: {})
      persist_updated_ids!(Array(ordered_recording_ids), actor: actor, metadata: metadata, action: "reordered")
    end

    def cleanup_missing_items!(actor: nil, metadata: {})
      persist_updated_ids!(normalized_mutation_ids, actor: actor, metadata: metadata, action: "cleaned")
    end

    def normalized_ordered_recording_ids
      parent_recording = resolved_parent_recording
      return normalized_array_ids.uniq unless parent_recording

      RecordingStudioOrderable::RecordingOrderManager.normalize_requested_ids(
        parent_recording,
        group_key,
        ordered_recording_ids
      )
    end

    def resolved_parent_recording
      @resolved_parent_recording ||= begin
        parent_recording_for_validation || RecordingStudio::Recording.find_by(id: parent_recording_id)
      rescue StandardError
        nil
      end
    end

    private

    def raw_owner_scope
      { owner_type: owner_type, owner_id: owner_id }
    end

    def resolved_owner
      return if owner_type.blank? || owner_id.blank?

      owner_type.safe_constantize&.find_by(id: owner_id)
    rescue StandardError
      nil
    end

    def normalized_mutation_ids
      normalized_ordered_recording_ids.dup
    end

    def resolved_mutation_ids
      parent_recording = resolved_parent_recording
      return normalized_mutation_ids unless parent_recording

      if current_attached_order_recording(self)
        return ordered_items_for_current_order(parent_recording).filter_map do |recording|
          normalize_recording_id(recording)
        end
      end

      Array(parent_recording.ordered_items_for(group_key, owner: raw_owner_scope)).filter_map do |recording|
        normalize_recording_id(recording)
      end
    end

    def persist_updated_ids!(recording_ids, actor:, metadata:, action:)
      parent_recording = resolved_parent_recording
      raise ArgumentError, "parent recording is required" unless parent_recording

      current_recording = current_order_recording_for_persistence(parent_recording)
      normalized_ids = RecordingStudioOrderable::RecordingOrderManager.normalize_requested_ids(
        parent_recording,
        group_key,
        recording_ids
      )

      if current_recording
        revised_recording = parent_recording.revise(current_recording, actor: actor, metadata: metadata) do |recordable|
          recordable.parent_recording_id = parent_recording.id
          recordable.parent_recording_for_validation = parent_recording
          recordable.recording_id_for_validation = current_recording.id
          recordable.group_key = group_key
          recordable.name = name
          recordable.owner_type = owner_type
          recordable.owner_id = owner_id
          recordable.ordered_recording_ids = normalized_ids
        end

        maybe_log_event!(parent_recording, revised_recording, action, metadata, actor)
        revised_recording.recordable
      else
        order_record = parent_recording.find_or_create_recording_order!(
          group_key,
          owner: raw_owner_scope,
          actor: actor,
          metadata: metadata,
          name: name,
          ordered_recording_ids: normalized_ids
        )
        maybe_log_event!(
          parent_recording,
          current_order_recording_for_persistence(parent_recording, fallback_order: order_record),
          action,
          metadata,
          actor
        )
        order_record
      end
    end

    def maybe_log_event!(parent_recording, order_recording, action, metadata, actor)
      return unless RecordingStudioOrderable.configuration.log_order_events
      return unless order_recording

      parent_recording.log_event(
        order_recording,
        action: "#{RecordingStudioOrderable.configuration.event_action_prefix}_#{action}",
        actor: actor,
        metadata: metadata.merge(group_key: group_key)
      )
    end

    def current_order_recording_for_persistence(parent_recording, fallback_order: self)
      current_recording = current_attached_order_recording(fallback_order)
      return current_recording if current_recording

      parent_recording.recording_order_recording_for(group_key, owner: raw_owner_scope)
    end

    def current_attached_order_recording(fallback_order)
      recordings = Array(fallback_order.recordings)

      recordings.compact.max_by do |recording|
        [
          recording.respond_to?(:updated_at) ? recording.updated_at : Time.at(0),
          recording.respond_to?(:created_at) ? recording.created_at : Time.at(0),
          recording.respond_to?(:id) ? recording.id.to_s : ""
        ]
      end
    rescue NameError
      nil
    end

    def ordered_items_for_current_order(parent_recording)
      eligible_items = RecordingStudioOrderable::RecordingOrderManager.eligible_items_for(
        parent_recording,
        group_key
      )
      eligible_by_id = eligible_items.index_by { |item_recording| item_recording.id.to_s }
      ordered_items = normalized_ordered_recording_ids.filter_map do |recording_id|
        eligible_by_id.delete(recording_id.to_s)
      end

      ordered_items + eligible_by_id.values
    end

    def move_relative!(moving:, anchor:, placement:, actor:, metadata:)
      ids = resolved_mutation_ids
      moving_id = normalize_recording_id(moving)
      anchor_id = normalize_recording_id(anchor)
      return self if moving_id.blank? || anchor_id.blank?

      ids.delete(moving_id)
      anchor_index = ids.index(anchor_id)
      return self unless anchor_index

      insert_index = placement == :before ? anchor_index : anchor_index + 1
      ids.insert(insert_index, moving_id)

      persist_updated_ids!(ids, actor: actor, metadata: metadata, action: "moved")
    end

    def normalize_ordered_recording_ids
      self.ordered_recording_ids = normalized_array_ids
    end

    def normalize_name
      self.name = name.to_s.strip.presence
    end

    def group_key_must_be_supported
      return if resolved_parent_recording.blank? || group_key.blank?

      RecordingStudioOrderable::RecordingOrderManager.resolve_group_definition!(resolved_parent_recording, group_key)
    rescue RecordingStudioOrderable::RecordingOrderManager::ConfigurationError => e
      errors.add(:group_key, e.message)
    end

    def order_scope_must_be_unique
      return if resolved_parent_recording.blank? || group_key.blank?
      return if name.present?

      matches = RecordingStudioOrderable::RecordingOrderManager.matching_order_recordings(
        resolved_parent_recording,
        group_key: group_key,
        owner: raw_owner_scope
      ).reject { |recording| recording.id == recording_id_for_validation }
      return if matches.empty?

      errors.add(:base, "an order already exists for this parent, group, and owner scope")
    end

    def ordered_recording_ids_must_be_unique
      return unless ordered_recording_ids.is_a?(Array)

      return unless ordered_recording_ids.uniq.length != ordered_recording_ids.length

      errors.add(:ordered_recording_ids, "must not contain duplicates")
    end

    def ordered_recording_ids_must_be_uuids
      Array(ordered_recording_ids).each do |recording_id|
        errors.add(:ordered_recording_ids, "must contain UUID values") unless recording_id.to_s.match?(UUID_FORMAT)
      end
    end

    def ordered_recording_ids_must_belong_to_eligible_items
      allowed_types = RecordingStudioOrderable::RecordingOrderManager.resolve_group_definition!(
        resolved_parent_recording,
        group_key
      ).fetch(:allows)
      ordered_ids = Array(ordered_recording_ids)
      recordings_by_id = RecordingStudio::Recording.where(id: ordered_ids).index_by { |recording| recording.id.to_s }
      own_recording_ids = Array(recordings).map { |recording| recording.id.to_s }
      own_recording_ids << recording_id_for_validation.to_s if recording_id_for_validation.present?

      ordered_ids.each do |recording_id|
        child_recording = recordings_by_id[recording_id.to_s]
        if child_recording.nil?
          errors.add(:ordered_recording_ids, "must reference existing RecordingStudio::Recording rows")
          next
        end

        if own_recording_ids.include?(child_recording.id.to_s)
          errors.add(:ordered_recording_ids, "cannot include the RecordingStudioOrder recording itself")
        end

        if child_recording.parent_recording_id != resolved_parent_recording.id
          errors.add(:ordered_recording_ids, "must only include direct children of the same parent recording")
        end

        if child_recording.root_recording_id != resolved_parent_recording.root_recording_id
          errors.add(:ordered_recording_ids, "must stay within the same root recording")
        end

        unless allowed_types.include?(child_recording.recordable_type)
          errors.add(:ordered_recording_ids, "must only include allowed recordable types for the group")
        end
      end
    end

    def normalize_recording_id(recording_or_id)
      RecordingStudioOrderable::RecordingOrderManager.normalize_recording_id(recording_or_id)
    end

    def normalized_array_ids
      Array(ordered_recording_ids).filter_map { |recording_id| normalize_recording_id(recording_id) }
    end

    alias ordered_items ordered_item_recordings
    alias include_recording! include_item!
    alias remove_recording! remove_item!
    alias reorder_recordings! reorder!
    alias cleanup! cleanup_missing_items!
  end
end
