ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

if ENV["COVERAGE_PART"] == "dummy"
  require "simplecov"
  repo = File.expand_path("../../..", __dir__)
  SimpleCov.start do
    root repo
    coverage_dir File.join(repo, "coverage/parts")
    command_name "Dummy MCP"
    enable_coverage :branch
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/db/"
    minimum_coverage 0
  end
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
