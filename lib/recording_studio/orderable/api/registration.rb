# frozen_string_literal: true

module RecordingStudio
  module Orderable
    module Api
      module Registration
        class << self
          def register!
            return unless defined?(RecordingStudioApi)

            RecordingStudioApi.configuration.each_api do |api|
              ACTIONS.each_key do |name|
                next if RecordingStudioApi.capability_action(name, api: api.name)

                RecordingStudioApi.register_capability_action(name, api: api.name, **capability_action_options(name))
              end
            end
          end

          private

          def capability_action_options(action_name)
            spec = ACTIONS.fetch(action_name)
            action_metadata(spec).merge(
              handler: spec.fetch(:handler),
              serializer: RecordingStudioApi::Serializers::ResourceRecordingSerializer,
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
                "403" => { description: spec.fetch(:forbidden) },
                "422" => { description: spec.fetch(:invalid) }
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
