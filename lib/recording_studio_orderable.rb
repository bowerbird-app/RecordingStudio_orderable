# frozen_string_literal: true

require "recording_studio"

require "recording_studio_orderable/version"
require "recording_studio_orderable/configuration"
require "recording_studio_orderable/recording_order_manager"
require "recording_studio_orderable/orderable_recordable"
require "recording_studio_orderable/recording_extensions"
require "recording_studio_orderable/engine"

module RecordingStudioOrderable
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
