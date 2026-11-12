# frozen_string_literal: true

module RecordingStudio
  module Orderable
    module Api
      module Errors
        module_function

        def wrap
          yield
        rescue RecordingStudioOrderable::NotAuthorized => e
          raise RecordingStudioApi::AuthorizationError, e.message
        rescue RecordingStudioOrderable::InvalidChild => e
          raise RecordingStudioApi::InvalidActionInputError, e.message
        end
      end
    end
  end
end
