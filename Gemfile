# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_orderable.gemspec
gemspec

gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v1.2.0"

gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
