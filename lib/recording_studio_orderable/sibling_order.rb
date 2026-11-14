# frozen_string_literal: true

module RecordingStudioOrderable
  class InvalidChild < StandardError; end

  class SiblingOrder
    POSITION_COLUMN = "recording_studio_orderable_position"

    def initialize(parent_recording)
      @parent_recording = parent_recording
    end

    def children
      ordered_relation(child_scope).preload(:recordable)
    end

    def reorder!(ordered_recording_ids:, actor: nil, impersonator: nil, metadata: {})
      authorize_reorder!(actor)
      with_parent_lock do
        eligible = current_eligible_recordings
        commit_order!(eligible, ordered_recording_ids, actor: actor, impersonator: impersonator, metadata: metadata)
      end
    end

    def move!(moving, to_index:, actor: nil, impersonator: nil, metadata: {})
      authorize_reorder!(actor)
      with_parent_lock do
        commit_explicit_move!(moving, to_index, actor: actor, impersonator: impersonator, metadata: metadata)
      end
    end

    def append!(moving, actor: nil, impersonator: nil, metadata: {})
      authorize_reorder!(actor)
      with_parent_lock do
        commit_explicit_move!(moving, :end, actor: actor, impersonator: impersonator, metadata: metadata)
      end
    end

    def assign_end_position!(recording)
      with_parent_lock do
        self.class.write_position!(recording, next_end_position(recording))
        parent_recording.reload
      end
    end

    def normalize_restored_position!(recording)
      with_parent_lock do
        position = recording.recording_studio_orderable_position
        next unless position.nil? || position_taken?(recording, position)

        self.class.write_position!(recording, next_end_position(recording))
      end
    end

    def self.write_position!(recording, position)
      if save_in_progress?(recording)
        recording.recording_studio_orderable_position = position
      else
        recording.update_columns(recording_studio_orderable_position: position)
      end
    end

    def self.save_in_progress?(recording)
      return true if recording.respond_to?(:will_save_change_to_parent_recording_id?) &&
                     recording.will_save_change_to_parent_recording_id?
      return true if recording.respond_to?(:will_save_change_to_trashed_at?) &&
                     recording.will_save_change_to_trashed_at?

      recording.respond_to?(:changed?) && recording.changed?
    end

    private

    attr_reader :parent_recording

    def authorize_reorder!(actor)
      resolved_actor = actor || current_actor
      return if RecordingStudioOrderable.authorized?(
        action: :reorder,
        actor: resolved_actor,
        recording: parent_recording
      )

      raise NotAuthorized, "Not authorized to reorder #{parent_recording.recordable_type}"
    end

    def current_actor
      return unless defined?(RecordingStudio)

      resolver = RecordingStudio.configuration.actor
      resolver.respond_to?(:call) ? resolver.call : nil
    end

    def with_parent_lock
      parent_recording.with_lock do
        @locked_child_scope = uncached_child_scope
        yield
      ensure
        @locked_child_scope = nil
      end
    end

    def commit_explicit_move!(moving, to_index, actor:, impersonator:, metadata:)
      eligible, child, moving_id, insertion_index, ordered = explicit_move_plan(moving, to_index)
      write_move!(eligible, child, ordered, insertion_index, append: to_index == :end)
      finish_order!(
        ordered,
        actor: actor,
        impersonator: impersonator,
        metadata: metadata.merge(moving_recording_id: moving_id, to_index: insertion_index),
        previous_ids: recording_ids(eligible)
      )
    end

    def explicit_move_plan(moving, to_index)
      eligible = current_eligible_recordings
      child = eligible_child!(eligible, moving)
      moving_id, insertion_index, ordered_ids = moved_id_list(eligible, child, to_index)
      [eligible, child, moving_id, insertion_index, recordings_for_ids(eligible, ordered_ids)]
    end

    def commit_order!(eligible, ordered_recording_ids, actor:, impersonator:, metadata:)
      ordered = resolve_ordered_recordings(eligible, ordered_recording_ids)
      write_changed_positions!(ordered)
      finish_order!(
        ordered,
        actor: actor,
        impersonator: impersonator,
        metadata: metadata,
        previous_ids: recording_ids(eligible)
      )
    end

    def finish_order!(ordered, actor:, impersonator:, metadata:, previous_ids:)
      log_reorder_event!(
        actor: actor,
        impersonator: impersonator,
        metadata: metadata,
        previous_ids: previous_ids,
        ordered_ids: recording_ids(ordered)
      )
      parent_recording.reload
    end

    def write_move!(eligible, child, ordered, to_index, append:)
      from_index = eligible.index(child)
      if append && other_positions_already_match?(ordered, child)
        assign_position!(child, to_index)
      elsif dense_positions?(eligible)
        shift_dense_span!(eligible, child, from_index, to_index)
      else
        write_changed_positions!(ordered)
      end
    end

    def other_positions_already_match?(ordered, child)
      child_id = child.id.to_s
      ordered.each_with_index.all? do |recording, index|
        recording.id.to_s == child_id || recording.recording_studio_orderable_position == index
      end
    end

    def dense_positions?(recordings)
      recordings.each_with_index.all? do |recording, index|
        recording.recording_studio_orderable_position == index
      end
    end

    def shift_dense_span!(eligible, child, from_index, to_index)
      return if from_index == to_index

      if from_index < to_index
        shift_position_range!(eligible, from_index + 1, to_index, -1, child)
      else
        shift_position_range!(eligible, to_index, from_index - 1, 1, child)
      end
      assign_position!(child, to_index)
    end

    def shift_position_range!(eligible, lower, upper, delta, except)
      position_scope(lower, upper, except).update_all(shift_assignment(delta))
      remember_shifted_positions!(eligible, lower, upper, delta, except)
    end

    def position_scope(lower, upper, except)
      child_scope.where(recording_studio_orderable_position: lower..upper).where.not(id: except.id)
    end

    def shift_assignment(delta)
      column = quoted_position_column
      operator = delta.negative? ? "-" : "+"
      "#{column} = #{column} #{operator} #{delta.abs}"
    end

    def write_changed_positions!(ordered)
      changes = changed_position_pairs(ordered)
      return if changes.empty?

      ids = changes.map { |recording, _position| recording.id }
      child_scope.where(id: ids).update_all(case_assignment(changes))
      changes.each { |recording, position| remember_position!(recording, position) }
    end

    def changed_position_pairs(ordered)
      ordered.each_with_index.filter_map do |recording, index|
        next if recording.recording_studio_orderable_position == index

        [recording, index]
      end
    end

    def case_assignment(changes)
      clauses = changes.map do |recording, position|
        "WHEN #{quoted_id(recording)} THEN #{position.to_i}"
      end
      "#{quoted_position_column} = CASE #{quoted_id_column} #{clauses.join(' ')} END"
    end

    def assign_position!(recording, position)
      return if recording.recording_studio_orderable_position == position

      self.class.write_position!(recording, position)
    end

    def remember_shifted_positions!(eligible, lower, upper, delta, except)
      except_id = except.id.to_s
      eligible.each do |recording|
        next if recording.id.to_s == except_id

        position = recording.recording_studio_orderable_position
        next unless position.is_a?(Integer) && position.between?(lower, upper)

        remember_position!(recording, position + delta)
      end
    end

    def remember_position!(recording, position)
      recording.recording_studio_orderable_position = position
      return unless recording.respond_to?(:clear_attribute_changes)

      recording.clear_attribute_changes([POSITION_COLUMN])
    end

    def recordings_for_ids(eligible, ids)
      by_id = eligible.index_by { |recording| recording.id.to_s }
      ids.map { |id| by_id.fetch(id.to_s) }
    end

    def quoted_position_column
      quote_column(POSITION_COLUMN)
    end

    def quoted_id_column
      quote_column("id")
    end

    def quote_column(name)
      return name unless parent_recording.class.respond_to?(:connection)

      parent_recording.class.connection.quote_column_name(name)
    end

    def quoted_id(recording)
      model = recording.class
      return model.connection.quote(recording.id) if model.respond_to?(:connection)

      quote_literal(recording.id)
    end

    def quote_literal(value)
      return value.to_i.to_s if value.is_a?(Integer)

      "'#{value.to_s.gsub("'", "''")}'"
    end

    def child_scope
      @locked_child_scope || uncached_child_scope
    end

    def uncached_child_scope
      scope = parent_recording.child_recordings.kept
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

    def current_eligible_recordings
      ordered_relation(child_scope).to_a
    end

    def next_end_position(recording)
      highest = child_scope.where.not(id: recording.id).maximum(:recording_studio_orderable_position)
      highest.nil? ? 0 : highest + 1
    end

    def position_taken?(recording, position)
      child_scope.where(recording_studio_orderable_position: position).where.not(id: recording.id).exists?
    end

    def eligible_child!(eligible, moving)
      moving_id = recording_id(moving)
      found = eligible.find { |recording| recording.id.to_s == moving_id }
      return found if found

      raise InvalidChild, "Recording #{moving_id} is not an eligible child of the orderable parent"
    end

    def recording_id(moving)
      moving.respond_to?(:id) ? moving.id.to_s : moving.to_s
    end

    def recording_ids(recordings)
      recordings.map { |recording| recording.id.to_s }
    end

    def resolve_ordered_recordings(eligible, ordered_recording_ids)
      eligible_by_id = eligible.index_by { |recording| recording.id.to_s }
      requested_ids = requested_eligible_ids(ordered_recording_ids, eligible_by_id)
      requested = requested_ids.map { |id| eligible_by_id.fetch(id) }

      requested + remaining_recordings(eligible, requested)
    end

    def requested_eligible_ids(ordered_recording_ids, eligible_by_id)
      requested_ids = Array(ordered_recording_ids).map(&:to_s)
      eligible_ids = requested_ids.uniq.select { |id| eligible_by_id.key?(id) }
      return eligible_ids if requested_ids == eligible_ids

      raise InvalidChild,
            "ordered_recording_ids includes an id that is missing, foreign, already-trashed, or duplicated."
    end

    def remaining_recordings(eligible, requested)
      (eligible - requested).sort_by { |recording| [recording.created_at || Time.at(0), recording.id.to_s] }
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

    def moved_id_list(eligible, moving, to_index)
      moving_id = moving.id.to_s
      ordered_ids = recording_ids(eligible)
      ordered_ids.delete(moving_id)
      insertion_index = insertion_index_for(to_index, ordered_ids.length)
      ordered_ids.insert(insertion_index, moving_id)
      [moving_id, insertion_index, ordered_ids]
    end

    def insertion_index_for(to_index, length)
      index = to_index == :end ? length : to_index.to_i
      index.clamp(0, length)
    end
  end
end
