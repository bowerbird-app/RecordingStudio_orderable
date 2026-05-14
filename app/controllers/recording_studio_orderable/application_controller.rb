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
      hook.call(self) if hook.respond_to?(:call)
    end

    def current_recording_studio_orderable_owner
      hook = RecordingStudioOrderable.configuration.current_owner_resolver
      hook.call(self) if hook.respond_to?(:call)
    end

    def ensure_current_recording_studio_orderable_owner!
      return if current_recording_studio_orderable_owner.present?

      redirect_to root_path, alert: "Authenticated owner is required."
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
  end
end
