# frozen_string_literal: true

require "recording_studio"
require "flat_pack"

require "recording_studio_orderable/version"
require "recording_studio_orderable/configuration"
require "recording_studio_orderable/authorization"
require "recording_studio_orderable/sibling_order"
require "recording_studio_orderable/engine"
require "recording_studio/orderable/capabilities/orderable"

module RecordingStudioOrderable
  class << self
    def install_recording_capabilities!
      return unless defined?(RecordingStudio::Recording)

      RecordingStudio.apply_capabilities!
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def authorized?(action:, actor:, recording:, controller: nil)
      Authorization.authorized?(
        action: action,
        actor: actor,
        recording: recording,
        controller: controller
      )
    end

    def capability_options_for(recording_or_type)
      type_name = capability_type_name(recording_or_type)
      return {} if type_name.blank?

      RecordingStudio.capability_options(:orderable, for: type_name).to_h.symbolize_keys
    rescue NoMethodError
      {}
    end

    private

    def capability_type_name(recording_or_type)
      return if recording_or_type.nil?
      return recording_or_type if recording_or_type.is_a?(String)
      return recording_or_type.to_s if recording_or_type.is_a?(Symbol)
      return recording_or_type.name if recording_or_type.is_a?(Class)
      return recording_or_type.recordable_type if recording_or_type.respond_to?(:recordable_type)

      recording_or_type.class.name
    end
  end
end

RecordingStudioOrderable.install_recording_capabilities!
