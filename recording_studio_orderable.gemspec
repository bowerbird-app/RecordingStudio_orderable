# frozen_string_literal: true

require_relative "lib/recording_studio_orderable/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_orderable"
  spec.version     = RecordingStudioOrderable::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_orderable"
  spec.summary     = "Opt-in sibling ordering addon for RecordingStudio"
  spec.description =
    "Recording Studio Orderable lets host recordables opt in to sibling position " \
    "for their children, with reorder history stored as Recording Studio events."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "flat_pack", ">= 0.1.74"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.1"
end
