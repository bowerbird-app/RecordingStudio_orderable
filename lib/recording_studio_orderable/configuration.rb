# frozen_string_literal: true

module RecordingStudioOrderable
  class ConfigurationLoadError < StandardError; end

  class Configuration
    attr_accessor :log_order_events,
                  :event_action_prefix

    def initialize
      @log_order_events = false
      @event_action_prefix = "recording_order"
    end

    def to_h
      {
        log_order_events: log_order_events,
        event_action_prefix: event_action_prefix
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
