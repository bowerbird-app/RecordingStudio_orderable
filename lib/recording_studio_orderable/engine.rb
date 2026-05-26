# frozen_string_literal: true

module RecordingStudioOrderable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioOrderable

    initializer "recording_studio_orderable.load_config" do |app|
      if app.respond_to?(:config_for)
        yaml = RecordingStudioOrderable::Engine.load_yaml_config(app)
        RecordingStudioOrderable.configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      x_config = app.config.x.try(:recording_studio_orderable)
      RecordingStudioOrderable.configuration.merge!(x_config.to_h) if x_config.respond_to?(:to_h)
    rescue StandardError => e
      raise RecordingStudioOrderable::ConfigurationLoadError,
            "Invalid recording_studio_orderable configuration: #{e.message}"
    end

    def self.load_yaml_config(app)
      app.config_for(:recording_studio_orderable)
    rescue RuntimeError => e
      raise unless e.message.include?("Could not load configuration. No such file")

      nil
    end

    initializer "recording_studio_orderable.integrate_recording_studio" do
      config.to_prepare do
        next unless defined?(RecordingStudio)

        RecordingStudio.register_recordable_type("RecordingStudio::RecordingStudioOrder")

        if RecordingStudio.respond_to?(:register_capability)
          begin
            RecordingStudio.register_capability(:recording_studio_orderable, RecordingStudioOrderable::RecordingExtensions)
            next
          rescue NoMethodError
            # Fall through for older or partially loaded RecordingStudio versions.
          end
        end

        next unless defined?(RecordingStudio::Recording)

        unless RecordingStudio::Recording.included_modules.include?(RecordingStudioOrderable::RecordingExtensions)
          RecordingStudio::Recording.include(RecordingStudioOrderable::RecordingExtensions)
        end
      end
    end
  end
end
