# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/dummy/**/*")
  t.verbose = false
end

namespace :app do
  desc "Run all tests for the gem"
  task test: :test
end

task default: :test
