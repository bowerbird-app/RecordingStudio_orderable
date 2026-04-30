# frozen_string_literal: true

module RecordingStudio
  class RecordingOrder < ActiveRecord::Base
    self.table_name = "recording_studio_recording_orders"

    UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    attr_accessor :parent_recording_for_validation

    has_many :recordings, as: :recordable, class_name: "RecordingStudio::Recording", inverse_of: :recordable

    validates :parent_recording_id, :order_group, presence: true
    validate :ordered_recording_ids_must_be_an_array
    validate :ordered_recording_ids_must_be_unique
    validate :ordered_recording_ids_must_be_uuids
    validate :ordered_recording_ids_must_belong_to_eligible_children, if: -> { parent_recording_for_validation.present? }

    before_validation :normalize_ordered_recording_ids

    def eligible_children
      resolved_parent_recording&.children_for_order_group(order_group) || []
    end

    def ordered_children
      resolved_parent_recording&.ordered_children_for(order_group) || []
    end

    def include_recording!(recording_or_id, at: nil, actor: nil, metadata: {})
      updated_ids = normalized_mutation_ids.tap do |ids|
        recording_id = normalize_recording_id(recording_or_id)
        ids.delete(recording_id)

        if at
          ids.insert([[at.to_i, 0].max, ids.length].min, recording_id)
        else
          ids << recording_id
        end
      end

      persist_updated_ids!(updated_ids, actor: actor, metadata: metadata, action: "included")
    end

    def remove_recording!(recording_or_id, actor: nil, metadata: {})
      updated_ids = normalized_mutation_ids - [normalize_recording_id(recording_or_id)]
      persist_updated_ids!(updated_ids, actor: actor, metadata: metadata, action: "removed")
    end

    def reorder_recordings!(recording_ids, actor: nil, metadata: {})
      persist_updated_ids!(Array(recording_ids), actor: actor, metadata: metadata, action: "reordered")
    end

    def move_recording_to!(recording_or_id, position, actor: nil, metadata: {})
      ids = normalized_mutation_ids
      recording_id = normalize_recording_id(recording_or_id)
      ids.delete(recording_id)
      ids.insert([[position.to_i, 0].max, ids.length].min, recording_id)

      persist_updated_ids!(ids, actor: actor, metadata: metadata, action: "moved")
    end

    def move_recording_higher!(recording_or_id, actor: nil, metadata: {})
      move_by_offset!(recording_or_id, -1, actor: actor, metadata: metadata)
    end

    def move_recording_lower!(recording_or_id, actor: nil, metadata: {})
      move_by_offset!(recording_or_id, 1, actor: actor, metadata: metadata)
    end

    def cleanup!(actor: nil, metadata: {})
      persist_updated_ids!(normalized_mutation_ids, actor: actor, metadata: metadata, action: "cleaned")
    end

    def normalized_ordered_recording_ids
      parent_recording = resolved_parent_recording
      return Array(ordered_recording_ids).filter_map { |recording_id| normalize_recording_id(recording_id) }.uniq unless parent_recording

      RecordingStudioOrderable::RecordingOrderManager.normalize_requested_ids(parent_recording, order_group, ordered_recording_ids)
    end

    def resolved_parent_recording
      @resolved_parent_recording ||= begin
        parent_recording_for_validation || RecordingStudio::Recording.find_by(id: parent_recording_id)
      rescue StandardError
        nil
      end
    end

    private

    def normalized_mutation_ids
      normalized_ordered_recording_ids.dup
    end

    def persist_updated_ids!(recording_ids, actor:, metadata:, action:)
      parent_recording = resolved_parent_recording
      raise ArgumentError, "parent recording is required" unless parent_recording

      current_order = parent_recording.recording_order_for(order_group) || self
      current_recording = parent_recording.recording_order_recording_for(order_group)
      normalized_ids = RecordingStudioOrderable::RecordingOrderManager.normalize_requested_ids(
        parent_recording,
        order_group,
        recording_ids
      )

      if current_recording
        revised_recording = parent_recording.revise(current_recording, actor: actor, metadata: metadata) do |recordable|
          recordable.parent_recording_id = parent_recording.id
          recordable.parent_recording_for_validation = parent_recording
          recordable.order_group = order_group
          recordable.ordered_recording_ids = normalized_ids
        end

        maybe_log_event!(parent_recording, revised_recording, action, metadata, actor)
        revised_recording.recordable
      else
        order_record = parent_recording.find_or_create_recording_order!(
          order_group,
          actor: actor,
          metadata: metadata,
          ordered_recording_ids: normalized_ids
        )
        maybe_log_event!(parent_recording, parent_recording.recording_order_recording_for(order_group), action, metadata, actor)
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
        metadata: metadata.merge(order_group: order_group)
      )
    end

    def move_by_offset!(recording_or_id, offset, actor:, metadata:)
      ids = normalized_mutation_ids
      recording_id = normalize_recording_id(recording_or_id)
      current_index = ids.index(recording_id)
      return self unless current_index

      target_index = [[current_index + offset, 0].max, ids.length - 1].min
      ids.delete_at(current_index)
      ids.insert(target_index, recording_id)

      persist_updated_ids!(ids, actor: actor, metadata: metadata, action: "moved")
    end

    def normalize_ordered_recording_ids
      self.ordered_recording_ids = Array(ordered_recording_ids).filter_map { |recording_id| normalize_recording_id(recording_id) }
    end

    def ordered_recording_ids_must_be_an_array
      errors.add(:ordered_recording_ids, "must be an array") unless ordered_recording_ids.is_a?(Array)
    end

    def ordered_recording_ids_must_be_unique
      return unless ordered_recording_ids.is_a?(Array)

      errors.add(:ordered_recording_ids, "must not contain duplicates") if ordered_recording_ids.uniq.length != ordered_recording_ids.length
    end

    def ordered_recording_ids_must_be_uuids
      Array(ordered_recording_ids).each do |recording_id|
        errors.add(:ordered_recording_ids, "must contain UUID values") unless recording_id.to_s.match?(UUID_FORMAT)
      end
    end

    def ordered_recording_ids_must_belong_to_eligible_children
      eligible_ids = parent_recording_for_validation.children_for_order_group(order_group).map { |recording| recording.id.to_s }
      invalid_ids = Array(ordered_recording_ids) - eligible_ids
      return if invalid_ids.empty?

      errors.add(:ordered_recording_ids, "must only include eligible direct child recordings")
    end

    def normalize_recording_id(recording_or_id)
      RecordingStudioOrderable::RecordingOrderManager.normalize_recording_id(recording_or_id)
    end
  end
end
