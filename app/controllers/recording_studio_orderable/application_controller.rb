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
      hook = RecordingStudioOrderable.configuration.authenticate_controller
      return hook.call(self) if hook.respond_to?(:call)

      ensure_recording_studio_actor_present!
    end

    def current_recording_studio_orderable_owner
      hook = RecordingStudioOrderable.configuration.current_owner_resolver
      return hook.call(self) if hook.respond_to?(:call)

      resolver = recording_studio_actor_resolver
      resolver.call if resolver.respond_to?(:call)
    end

    def recording_studio_actor_resolver
      return unless defined?(RecordingStudio)

      RecordingStudio.configuration&.actor
    end

    def ensure_recording_studio_actor_present!
      resolver = recording_studio_actor_resolver
      actor = resolver.call if resolver.respond_to?(:call)
      return if actor.present?

      redirect_to root_path, alert: "Authentication is required."
    end

    def ensure_current_recording_studio_orderable_owner!
      return if current_recording_studio_orderable_owner.present?

      redirect_to root_path, alert: "Authenticated owner is required."
    end

    def authorize_parent_recording!(parent_recording)
      hook = RecordingStudioOrderable.configuration.authorize_parent_recording
      unless hook.respond_to?(:call)
        redirect_parent_recording_access_denied
        return
      end

      result = hook.call(self, parent_recording)
      return if result || performed?

      redirect_parent_recording_access_denied
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
