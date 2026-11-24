# frozen_string_literal: true

module RecordingStudioOrderable
  class ParentPosition
    def self.sync(recording, clear: true)
      new(recording).sync(clear: clear)
    end

    def self.with_create_lock(parent, recordable, &)
      return yield unless assigns_end_position?(parent, child_type(recordable))

      parent.with_lock(&)
    end

    def self.assigns_end_position?(parent, child_type)
      return false unless parent
      return false unless orderable_parent?(parent)

      allowed = allowed_child_types(parent)
      allowed.empty? || allowed.include?(child_type.to_s)
    end

    def self.child_type(recordable)
      RecordingStudio::Identity.type_name_for(recordable)
    end

    def self.orderable_parent?(parent)
      return false unless defined?(RecordingStudio)
      return false unless parent.respond_to?(:recordable_type)

      RecordingStudio.capability_enabled?(:orderable, for: parent.recordable_type)
    end

    def self.allowed_child_types(parent)
      Array(RecordingStudioOrderable.capability_options_for(parent)[:allows]).map(&:to_s).reject(&:blank?)
    end

    def initialize(recording)
      @recording = recording
    end

    def sync(clear: true)
      parent = recording.parent_recording if recording.respond_to?(:parent_recording)
      if append_to?(parent)
        SiblingOrder.new(parent).assign_end_position!(recording)
      elsif clear
        clear_position!
      end
    end

    private

    attr_reader :recording

    def append_to?(parent)
      return false unless parent
      return false unless recording.respond_to?(:recordable_type)

      self.class.assigns_end_position?(parent, recording.recordable_type)
    end

    def clear_position!
      return unless recording.respond_to?(:recording_studio_orderable_position)
      return if recording.recording_studio_orderable_position.nil?

      SiblingOrder.write_position!(recording, nil)
    end
  end
end
