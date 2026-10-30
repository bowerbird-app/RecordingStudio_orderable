# frozen_string_literal: true

module RecordingStudioOrderable
  class ApplicationController < ActionController::Base
    recording_studio_layout { RecordingStudioOrderable.configuration.layout }

    protect_from_forgery with: :exception

    rescue_from RecordingStudioOrderable::NotAuthorized, with: :recording_studio_orderable_forbidden

    private

    def recording_studio_orderable_forbidden(_error)
      head :forbidden
    end
  end
end
