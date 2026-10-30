# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.332"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"

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
