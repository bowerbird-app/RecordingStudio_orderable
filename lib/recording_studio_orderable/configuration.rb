# frozen_string_literal: true

module RecordingStudioOrderable
  class ConfigurationLoadError < StandardError; end

  class Configuration
    attr_accessor :log_order_events,
                  :event_action,
                  :authorization_resolver,
                  :use_recording_studio_accessible,
                  :authorization_role

    def initialize
      @log_order_events = true
      @event_action = "reordered"
      @authorization_resolver = nil
      @use_recording_studio_accessible = true
      @authorization_role = :edit
    end

    def to_h
      {
        log_order_events: log_order_events,
        event_action: event_action,
        authorization_resolver: authorization_resolver,
        use_recording_studio_accessible: use_recording_studio_accessible,
        authorization_role: authorization_role
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
