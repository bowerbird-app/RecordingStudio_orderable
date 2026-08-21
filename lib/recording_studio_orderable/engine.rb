# frozen_string_literal: true

module RecordingStudioOrderable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioOrderable

    initializer "recording_studio_orderable.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      importmap_path = Engine.root.join("config/importmap.rb")
      javascript_path = Engine.root.join("app/javascript")
      app.config.importmap.paths << importmap_path if importmap_path.exist?
      app.config.assets.paths << javascript_path if javascript_path.directory?
    end

    config.to_prepare do
      RecordingStudioOrderable.install_recording_capabilities!
    end

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

    class << self
      def load_yaml_config(app)
        app.config_for(:recording_studio_orderable)
      rescue RuntimeError => e
        raise unless e.message.include?("Could not load configuration. No such file")

        nil
      end
    end
  end
end
