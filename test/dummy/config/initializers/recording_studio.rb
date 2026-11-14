# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.app_name = "Orderable Demo" if config.respond_to?(:app_name=)
  config.recordable_types = %w[Workspace Project Folder Page]
  config.recordable_types += %w[
    RecordingStudio::Access
    RecordingStudioApi::ApiClient
    RecordingStudioApi::ApiCredential
    RecordingStudioApi::ApiAccessToken
  ] if defined?(RecordingStudioApi)
  config.actor = -> { Current.actor }
  config.authorize_write = ->(actor:, **) { actor.present? }
  config.event_notifications_enabled = true
  config.idempotency_mode = :return_existing
  config.recordable_dup_strategy = :dup
  config.require_actor = true if config.respond_to?(:require_actor=)
  config.max_metadata_bytes = 16_384 if config.respond_to?(:max_metadata_bytes=)
end

# Trashable 0.16 registers this filter. That tag is not published, so the
# dummy stays on v0.14.0 and registers the same condition Recording.kept uses.
RecordingStudio.register_recording_filter(:trashable, sql: lambda { |table|
  "#{table}.trashed_at IS NULL"
}) do |recordings|
  recordings.where(trashed_at: nil)
end
