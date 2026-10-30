# frozen_string_literal: true

module RecordingStudioOrderable
  class ParentPosition
    def self.sync(recording)
      new(recording).sync
    end

    def initialize(recording)
      @recording = recording
    end

    def sync
      parent = recording.parent_recording if recording.respond_to?(:parent_recording)
      if append_to?(parent)
        SiblingOrder.new(parent).assign_end_position!(recording)
      else
        clear_position!
      end
    end

    private

    attr_reader :recording

    def append_to?(parent)
      return false unless parent
      return false unless orderable_parent?(parent)

      allowed = allowed_child_types(parent)
      allowed.empty? || allowed.include?(recording.recordable_type.to_s)
    end

    def orderable_parent?(parent)
      return false unless defined?(RecordingStudio)

      RecordingStudio.capability_enabled?(:orderable, for: parent.recordable_type)
    end

    def allowed_child_types(parent)
      Array(RecordingStudioOrderable.capability_options_for(parent)[:allows]).map(&:to_s).reject(&:blank?)
    end

    def clear_position!
      return unless recording.respond_to?(:recording_studio_orderable_position)
      return if recording.recording_studio_orderable_position.nil?

      SiblingOrder.write_position!(recording, nil)
    end
  end
end
