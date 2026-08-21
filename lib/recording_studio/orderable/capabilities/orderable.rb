# frozen_string_literal: true

module RecordingStudio
  module Orderable
    module Capabilities
      module Orderable
        def self.to(**options)
          build_capability_module(capability_options(options))
        end

        def self.build_capability_module(options)
          Module.new do
            extend ActiveSupport::Concern

            included do |base|
              RecordingStudio::Orderable::Capabilities::Orderable.apply_capability(base, options)
            end
          end
        end

        def self.apply_capability(base, options)
          RecordingStudio.enable_capability(:orderable, on: base.name)
          RecordingStudio.set_capability_options(:orderable, on: base.name, **options)
        end

        def self.capability_options(options)
          normalized = options.to_h.transform_keys(&:to_sym)
          return normalized unless normalized.key?(:allows)

          normalized.merge(allows: Array(normalized[:allows]).map { |type| type.is_a?(Class) ? type.name : type.to_s })
        end

        module RecordingMethods
          include RecordingStudio::Capability

          def recording_studio_orderable_children
            recording_studio_orderable_assert_capability!
            RecordingStudioOrderable::SiblingOrder.new(self).children
          end

          def recording_studio_orderable_reorder!(ordered_recording_ids:, actor: nil, impersonator: nil, metadata: {})
            recording_studio_orderable_assert_capability!
            recording_studio_orderable_authorize!(:reorder, actor: actor)
            RecordingStudioOrderable::SiblingOrder.new(self).reorder!(
              ordered_recording_ids: ordered_recording_ids,
              actor: actor,
              impersonator: impersonator,
              metadata: metadata
            )
          end

          def recording_studio_orderable_move!(moving, to_index:, actor: nil, impersonator: nil, metadata: {})
            recording_studio_orderable_assert_capability!
            recording_studio_orderable_authorize!(:reorder, actor: actor)
            RecordingStudioOrderable::SiblingOrder.new(self).move!(
              moving,
              to_index: to_index,
              actor: actor,
              impersonator: impersonator,
              metadata: metadata
            )
          end

          private

          def recording_studio_orderable_assert_capability!
            assert_capability!(:orderable)
          end

          def recording_studio_orderable_authorize!(action, actor: nil)
            resolved_actor = actor || recording_studio_orderable_current_actor
            return if RecordingStudioOrderable.authorized?(
              action: action,
              actor: resolved_actor,
              recording: self
            )

            raise ArgumentError, "Not authorized to #{action} #{recordable_type}"
          end

          def recording_studio_orderable_current_actor
            return unless defined?(RecordingStudioOrderable::Authorization)

            resolver = RecordingStudio.configuration.actor if defined?(RecordingStudio)
            resolver.respond_to?(:call) ? resolver.call : nil
          end
        end
      end
    end
  end
end

module RecordingStudio
  module Capabilities
    Orderable = RecordingStudio::Orderable::Capabilities::Orderable
  end
end

RecordingStudio.register_capability(
  :orderable,
  RecordingStudio::Orderable::Capabilities::Orderable::RecordingMethods,
  source: "recording_studio_orderable"
)
