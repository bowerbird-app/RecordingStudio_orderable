# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.332"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.5.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.2"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.7.3"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.3"

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock", require: false
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
