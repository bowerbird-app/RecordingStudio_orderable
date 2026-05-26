# frozen_string_literal: true

require "uri"

module RecordingStudioOrderable
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout :recording_studio_orderable_layout

    before_action :authenticate_recording_studio_orderable_request!

    helper_method :current_recording_studio_orderable_owner

    private

    def recording_studio_orderable_layout
      "application"
    end

    def authenticate_recording_studio_orderable_request!
      ensure_recording_studio_actor_present!
    end

    def current_recording_studio_orderable_owner
      resolver = recording_studio_actor_resolver
      owner = resolver.call if resolver.respond_to?(:call)
      return owner if owner.present?

      controller_current_user
    end

    def recording_studio_actor_resolver
      return unless defined?(RecordingStudio)

      RecordingStudio.configuration&.actor
    end

    def controller_current_user
      return unless respond_to?(:current_user, true)

      send(:current_user)
    end

    def ensure_recording_studio_actor_present!
      actor = resolve_recording_studio_actor

      if actor.blank?
        sync_recording_studio_actor_from_current_user
        actor = resolve_recording_studio_actor
      end

      return if actor.present?

      redirect_to root_path, alert: "Authentication is required."
    end

    def resolve_recording_studio_actor
      resolver = recording_studio_actor_resolver
      resolver.call if resolver.respond_to?(:call)
    end

    def sync_recording_studio_actor_from_current_user
      return unless defined?(Current)
      return unless Current.respond_to?(:actor) && Current.respond_to?(:actor=)
      return if Current.actor.present?

      owner = controller_current_user
      Current.actor = owner if owner.present?
    end

    def ensure_current_recording_studio_orderable_owner!
      return if current_recording_studio_orderable_owner.present?

      redirect_to root_path, alert: "Authenticated owner is required."
    end

    def authorize_parent_recording!(parent_recording)
      return redirect_parent_recording_access_denied unless recording_studio_accessible_authorized?(parent_recording)

      nil if performed?
    end

    def recording_studio_accessible_authorized?(parent_recording)
      return false unless defined?(RecordingStudioAccessible)
      return false unless RecordingStudioAccessible.respond_to?(:authorized?)

      actor = current_recording_studio_orderable_owner
      return false unless actor.present? && parent_recording.present?

      RecordingStudioAccessible.authorized?(actor: actor, recording: parent_recording, role: :admin)
    rescue StandardError
      false
    end

    def safe_local_redirect_target(target)
      value = target.to_s.strip
      return if value.blank?
      return unless value.start_with?("/")

      uri = URI.parse(value)
      return if uri.scheme.present? || uri.host.present?

      value
    rescue URI::InvalidURIError
      nil
    end

    def append_query_param(path, key, value)
      return path if path.blank? || value.blank?

      separator = path.include?("?") ? "&" : "?"
      "#{path}#{separator}#{key}=#{ERB::Util.url_encode(value.to_s)}"
    end

    def redirect_parent_recording_access_denied
      redirect_to root_path, alert: "You are not allowed to access that recording order."
    end
  end
end
