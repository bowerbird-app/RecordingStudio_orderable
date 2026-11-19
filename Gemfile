# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.56.0"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.10.0"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.2.3"

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock", require: false
  gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.19.1"
  gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v1.19.0"
  gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.5.0"
  gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.8.2"
  gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.0.3"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
