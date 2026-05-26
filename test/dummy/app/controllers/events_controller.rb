# frozen_string_literal: true

class EventsController < ApplicationController
  EVENTS_LIMIT = 200

  def index
    @events = recent_events.limit(EVENTS_LIMIT).map do |event|
      {
        occurred_at: event.occurred_at,
        action: event.action,
        recording_id: event.recording_id,
        recordable: [event.recordable_type, event.recordable_id].compact.join(" #"),
        actor: [event.actor_type, event.actor_id].compact.join(" #"),
        metadata: format_metadata(event.metadata)
      }
    end
  end

  private

  def recent_events
    RecordingStudio::Event
      .order(occurred_at: :desc, created_at: :desc)
  end

  def format_metadata(metadata)
    return "-" if metadata.blank?

    JSON.generate(metadata)
  rescue JSON::GeneratorError
    metadata.to_s
  end
end
