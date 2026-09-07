# frozen_string_literal: true

module RecordingStudioOrderable
  class SiblingOrder
    def initialize(parent_recording)
      @parent_recording = parent_recording
    end

    def children
      ordered_relation(child_scope)
    end

    def reorder!(ordered_recording_ids:, actor: nil, impersonator: nil, metadata: {})
      eligible = child_scope.to_a
      ordered = resolve_ordered_recordings(eligible, ordered_recording_ids)
      persist_and_log!(
        ordered,
        actor: actor,
        impersonator: impersonator,
        metadata: metadata,
        previous_ids: sorted_ids(eligible)
      )
    end

    def move!(moving, to_index:, actor: nil, impersonator: nil, metadata: {})
      moving_id, insertion_index, ordered_ids = moved_id_list(moving, to_index)
      reorder!(
        ordered_recording_ids: ordered_ids,
        actor: actor,
        impersonator: impersonator,
        metadata: metadata.merge(moving_recording_id: moving_id, to_index: insertion_index)
      )
    end

    def append!(moving, actor: nil, impersonator: nil, metadata: {})
      move!(moving, to_index: children.to_a.size, actor: actor, impersonator: impersonator, metadata: metadata)
    end

    private

    attr_reader :parent_recording

    def persist_and_log!(ordered, actor:, impersonator:, metadata:, previous_ids:)
      persist_positions!(ordered)
      log_reorder_event!(
        actor: actor,
        impersonator: impersonator,
        metadata: metadata,
        previous_ids: previous_ids,
        ordered_ids: ordered.map { |recording| recording.id.to_s }
      )
      parent_recording.reload
    end

    def child_scope
      scope = parent_recording.child_recordings
      allowed_types = allowed_child_types
      return scope if allowed_types.empty?

      scope.where(recordable_type: allowed_types)
    end

    def allowed_child_types
      Array(capability_options_hash[:allows]).map(&:to_s).reject(&:blank?)
    end

    def capability_options_hash
      options = if parent_recording.respond_to?(:capability_options)
                  parent_recording.capability_options(:orderable)
                else
                  RecordingStudio.capability_options(:orderable, for: parent_recording.recordable_type)
                end

      options.to_h.symbolize_keys
    end

    def ordered_relation(scope)
      scope.reorder(:recording_studio_orderable_position, :created_at, :id)
    end

    def resolve_ordered_recordings(eligible, ordered_recording_ids)
      eligible_by_id = eligible.index_by { |recording| recording.id.to_s }
      requested_ids = requested_eligible_ids(ordered_recording_ids, eligible_by_id)
      requested = requested_ids.map { |id| eligible_by_id.fetch(id) }

      requested + remaining_recordings(eligible, requested)
    end

    def requested_eligible_ids(ordered_recording_ids, eligible_by_id)
      Array(ordered_recording_ids).map(&:to_s).uniq.select { |id| eligible_by_id.key?(id) }
    end

    def remaining_recordings(eligible, requested)
      (eligible - requested).sort_by { |recording| [recording.created_at || Time.at(0), recording.id.to_s] }
    end

    def persist_positions!(ordered)
      parent_recording.class.transaction do
        ordered.each_with_index do |recording, index|
          recording.update!(recording_studio_orderable_position: index)
        end
      end
    end

    def log_reorder_event!(actor:, impersonator:, metadata:, previous_ids:, ordered_ids:)
      return unless RecordingStudioOrderable.configuration.log_order_events
      return unless parent_recording.respond_to?(:log_event!)

      parent_recording.log_event!(
        action: RecordingStudioOrderable.configuration.event_action.to_s,
        actor: actor,
        impersonator: impersonator,
        metadata: event_metadata(metadata, previous_ids, ordered_ids)
      )
    end

    def event_metadata(metadata, previous_ids, ordered_ids)
      metadata.to_h.merge(
        ordered_recording_ids: ordered_ids,
        previous_ordered_recording_ids: previous_ids
      )
    end

    def sorted_ids(recordings)
      ids_from_relation(recordings)
    rescue StandardError
      fallback_sorted_ids(recordings)
    end

    def ids_from_relation(recordings)
      ordered_relation(parent_recording.class.where(id: recordings.map(&:id))).map do |recording|
        recording.id.to_s
      end
    end

    def fallback_sorted_ids(recordings)
      recordings.sort_by { |recording| sort_key_for(recording) }.map { |recording| recording.id.to_s }
    end

    def sort_key_for(recording)
      [recording.recording_studio_orderable_position || Float::INFINITY, recording.created_at || Time.at(0),
       recording.id.to_s]
    end

    def moved_id_list(moving, to_index)
      moving_id = moving.respond_to?(:id) ? moving.id.to_s : moving.to_s
      ordered_ids = children.map { |recording| recording.id.to_s }
      ordered_ids.delete(moving_id)
      insertion_index = to_index.to_i.clamp(0, ordered_ids.length)
      ordered_ids.insert(insertion_index, moving_id)
      [moving_id, insertion_index, ordered_ids]
    end
  end
end
