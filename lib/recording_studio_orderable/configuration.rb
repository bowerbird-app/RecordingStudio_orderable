# frozen_string_literal: true

module RecordingStudioOrderable
  class ConfigurationLoadError < StandardError; end

  class Configuration
    attr_accessor :log_order_events,
                  :event_action_prefix,
                  :authenticate_controller,
                  :current_owner_resolver,
                  :authorize_parent_recording

    def initialize
      @log_order_events = false
      @event_action_prefix = "recording_order"
      @authenticate_controller = nil
      @current_owner_resolver = nil
      @authorize_parent_recording = nil
    end

    def to_h
      {
        log_order_events: log_order_events,
        event_action_prefix: event_action_prefix,
        authenticate_controller: authenticate_controller,
        current_owner_resolver: current_owner_resolver,
        authorize_parent_recording: authorize_parent_recording
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end
  end
end
