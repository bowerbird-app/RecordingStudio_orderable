# frozen_string_literal: true

module RecordingStudio
  module Orderable
    module Api
      module OpenapiOverrides
        class << self
          def store(type:, action:, title:, description:)
            type_name = normalized_type!(type)
            name = normalized_action!(action)
            raise ArgumentError, "title is required" if title.nil?
            raise ArgumentError, "description is required" if description.nil?

            entries[type_name] ||= {}
            entries[type_name][name] = { title: title, description: description }.freeze
          end

          def document(action, type: nil)
            base = generic_openapi(action).deep_dup
            overlay = fetch(type, action)
            overlay ? base.merge(overlay) : base
          end

          def reset!
            @entries = {}
          end

          private

          def fetch(type, action)
            return if type.nil?

            entries.dig(type.to_s, action.to_sym)
          end

          def entries
            @entries ||= {}
          end

          def normalized_type!(type)
            type_name = type.to_s
            raise ArgumentError, "type is required" if type_name.strip.empty?

            type_name
          end

          def normalized_action!(action)
            name = action.to_sym
            raise ArgumentError, "Unknown Orderable action #{action.inspect}" unless ACTIONS.key?(name)

            name
          end

          def generic_openapi(action)
            spec = ACTIONS.fetch(action.to_sym)
            {
              summary: spec.fetch(:summary),
              description: spec.fetch(:description),
              responses: responses_for(spec)
            }
          end

          def responses_for(spec)
            {
              "200" => { description: spec.fetch(:success) },
              "403" => { description: spec.fetch(:forbidden) },
              "422" => { description: spec.fetch(:invalid) }
            }
          end
        end
      end
    end
  end
end
