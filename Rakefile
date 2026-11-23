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
  dummy_env = {
    "COVERAGE_PART" => "dummy",
    "BUNDLE_GEMFILE" => File.expand_path("test/dummy/Gemfile", __dir__),
    "RAILS_ENV" => "test"
  }
  Dir.chdir("test/dummy") do
    passed = system(dummy_env, "bundle exec rails test test/orderable_mcp_tools_test.rb")
    abort "dummy named MCP tool tests failed" unless passed
  end
end

namespace :app do
  desc "Run gem tests, then the dummy named MCP tool tests"
  task test: :test
end

task default: :test
