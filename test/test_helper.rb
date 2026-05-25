# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift File.expand_path("../vendor/bundle/ruby/3.3.0/bundler/gems/RecordingStudio-2d66dcb4e6b2/lib",
                                    __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "recording_studio_orderable"
