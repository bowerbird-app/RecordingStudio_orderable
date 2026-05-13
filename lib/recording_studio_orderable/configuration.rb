# frozen_string_literal: true

module RecordingStudioOrderable
  class Configuration
    attr_accessor :log_order_events, :event_action_prefix, :authenticate_controller, :current_owner_resolver

    def initialize
      @log_order_events = false
      @event_action_prefix = "recording_order"
      @authenticate_controller = nil
      @current_owner_resolver = nil
    end

    def to_h
      {
        log_order_events: log_order_events,
        event_action_prefix: event_action_prefix,
        authenticate_controller: authenticate_controller,
        current_owner_resolver: current_owner_resolver
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
