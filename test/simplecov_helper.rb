# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  enable_coverage :branch
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/db/"
  if ENV["COVERAGE_PART"] == "unit"
    command_name "Unit Tests"
    coverage_dir "coverage/parts"
    minimum_coverage 0
  else
    minimum_coverage line: 94
  end
end
