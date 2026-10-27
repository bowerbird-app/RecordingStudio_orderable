# frozen_string_literal: true

module RecordingStudioOrderable
  class ApplicationController < ActionController::Base
    recording_studio_layout { RecordingStudioOrderable.configuration.layout }

    protect_from_forgery with: :exception
  end
end
