# frozen_string_literal: true

module RecordingStudioOrderable
  class ApplicationController < ActionController::Base
    include RecordingStudio::UsesDefaultLayout

    protect_from_forgery with: :exception
  end
end
