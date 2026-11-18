# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.378"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v7.7.1"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.54.1"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.9.2"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.2.1"

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock", require: false
  gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.19.0"
  gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v1.16.0"
  gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.4.2"
  gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.8.1"
  gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.0.2"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
