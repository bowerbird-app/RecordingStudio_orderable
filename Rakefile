# frozen_string_literal: true

require "bundler/gem_tasks"
require "fileutils"
require "rake/testtask"

Rake::TestTask.new(:unit) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/dummy/**/*")
  t.verbose = false
end

task :test do
  FileUtils.rm_rf("coverage/parts")
  ENV["COVERAGE_PART"] = "unit"
  Rake::Task[:unit].invoke
  run_dummy_mcp_tests
  check_merged_coverage
end

def run_dummy_mcp_tests
  bundle_path = ENV.fetch("BUNDLE_PATH", nil)
  bundle_path = File.expand_path(bundle_path) if bundle_path
  Bundler.with_unbundled_env do
    Dir.chdir("test/dummy") do
      run_dummy_mcp_suite(bundle_path)
    end
  end
end

def run_dummy_mcp_suite(bundle_path)
  passed = system(dummy_test_env(bundle_path), "bundle", "exec", "rails", "test", "test/orderable_mcp_tools_test.rb")
  abort "dummy named MCP tool tests failed" unless passed
end

def dummy_test_env(bundle_path)
  env = {
    "COVERAGE_PART" => "dummy",
    "BUNDLE_GEMFILE" => File.expand_path("test/dummy/Gemfile", __dir__),
    "RAILS_ENV" => "test"
  }
  env["BUNDLE_PATH"] = bundle_path if bundle_path
  env
end

def check_merged_coverage
  require "simplecov"
  SimpleCov.collate(Dir["coverage/parts/.resultset.json"]) do
    enable_coverage :branch
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/db/"
    minimum_coverage line: 94
  end
end

namespace :app do
  desc "Run gem tests, then the dummy named MCP tool tests"
  task test: :test
end

task default: :test
