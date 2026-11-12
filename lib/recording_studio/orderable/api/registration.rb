# frozen_string_literal: true

module RecordingStudio
  module Orderable
    module Api
      module Registration
        class << self
          def register!
            api = api_engine
            return unless api_available?(api)

            surfaces(api).each do |api_name|
              ACTIONS.each_key { |action_name| register_action(api, api_name, action_name) }
            end
          end

          private

          def api_engine
            RecordingStudioApi if defined?(RecordingStudioApi)
          end

          def api_available?(api)
            return false unless api.respond_to?(:capability_action)
            return false unless api.respond_to?(:register_capability_action)

            serializer_for(api)
          end

          def serializer_for(api)
            api::Serializers::ResourceRecordingSerializer if api.const_defined?(:Serializers)
          rescue NameError
            nil
          end

          def surfaces(api)
            return [nil] unless named_api_registration_supported?(api)

            names = []
            api.configuration.each_api { |definition| names << definition.name }
            names
          end

          def named_api_registration_supported?(api)
            api.respond_to?(:configuration) &&
              api.configuration.respond_to?(:each_api) &&
              action_api_accepts_api?(api, :capability_action) &&
              action_api_accepts_api?(api, :register_capability_action)
          end

          def action_api_accepts_api?(api, method_name)
            api.method(method_name).parameters.any? do |type, name|
              type == :keyrest || (name == :api && %i[key keyreq].include?(type))
            end
          end

          def register_action(api, api_name, action_name)
            return if existing_action(api, api_name, action_name)

            options = capability_action_options(api, action_name)
            if api_name
              api.register_capability_action(action_name, api: api_name, **options)
            else
              api.register_capability_action(action_name, **options)
            end
          end

          def existing_action(api, api_name, action_name)
            if api_name
              api.capability_action(action_name, api: api_name)
            else
              api.capability_action(action_name)
            end
          end

          def capability_action_options(api, action_name)
            spec = ACTIONS.fetch(action_name)
            action_metadata(spec).merge(
              handler: spec.fetch(:handler),
              serializer: serializer_for(api),
              input_contract: { reject_unknown: false, fields: spec.fetch(:fields) },
              openapi: openapi_for(spec)
            )
          end

          def openapi_for(spec)
            {
              summary: spec.fetch(:summary),
              description: spec.fetch(:description),
              responses: {
                "200" => { description: spec.fetch(:success) },
                "403" => { description: "API access is not authorized to reorder this recording." },
                "422" => { description: "Reorder request is invalid." }
              }
            }
          end

          def action_metadata(spec)
            {
              capability: :orderable,
              version: ACTION_VERSION,
              version_notes: [spec.fetch(:description)],
              http_verb: :post,
              scope: :member,
              required_role: RecordingStudioOrderable.configuration.authorization_role
            }
          end
        end
      end
    end
  end
end
