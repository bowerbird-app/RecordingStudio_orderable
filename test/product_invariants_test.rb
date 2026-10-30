# frozen_string_literal: true

require "test_helper"

class ProductInvariantsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_gemspec_names_the_addon
    gemspec = File.read(File.join(ROOT, "recording_studio_orderable.gemspec"))

    assert_match(/spec\.name\s*=\s*"recording_studio_orderable"/, gemspec)
    assert_match(/RecordingStudioOrderable::VERSION/, gemspec)
    assert_match(/\A\d+\.\d+\.\d+\z/, RecordingStudioOrderable::VERSION)
  end

  def test_engine_isolates_the_addon_namespace
    engine = File.read(File.join(ROOT, "lib/recording_studio_orderable/engine.rb"))

    assert_match(/^module RecordingStudioOrderable$/, engine)
    assert_match(/isolate_namespace RecordingStudioOrderable/, engine)
  end

  def test_template_code_paths_are_gone
    refute File.exist?(File.join(ROOT, "gem_template.gemspec"))
    refute File.exist?(File.join(ROOT, "lib/gem_template.rb"))
    refute File.directory?(File.join(ROOT, "lib/gem_template"))
    refute File.directory?(File.join(ROOT, "app/controllers/gem_template"))
    refute File.exist?(File.join(ROOT, "test/dummy/app/javascript/controllers/hello_controller.js"))
    refute File.exist?(File.join(ROOT, "test/dummy/bin/thrust"))
    refute File.directory?(File.join(ROOT, "test/dummy/app/views/pwa"))
    refute File.directory?(File.join(ROOT, "test/dummy/app/views/makeup_artist"))
  end

  def test_rubocop_does_not_exclude_template_paths
    config = File.read(File.join(ROOT, ".rubocop.yml"))

    refute_includes config, "gem_template"
    refute_includes config, "test/services"
  end

  def test_ci_uses_the_addon_database_and_runs_security_scans
    workflow = File.read(File.join(ROOT, ".github/workflows/ci.yml"))

    assert_includes workflow, "recording_studio_orderable_test"
    refute_includes workflow, "gem_template_test"
    assert_includes workflow, "bin/bundler-audit"
    assert_includes workflow, "bin/brakeman"
    assert_includes workflow, "bundle exec rubocop"
    assert_includes workflow, "bundle exec rake app:test"
    assert_includes workflow, "bundle exec rails test"
  end

  def test_dummy_database_defaults_use_the_addon_name
    database = File.read(File.join(ROOT, "test/dummy/config/database.yml"))

    assert_includes database, "recording_studio_orderable_development"
    assert_includes database, "recording_studio_orderable_test"
    refute_includes database, "app_development"
    refute_includes database, "app_test"

    compose = File.read(File.join(ROOT, ".devcontainer/docker-compose.yml"))
    assert_includes compose, "recording_studio_orderable_development"
    refute_includes compose, "app_development"
  end

  def test_dummy_gemfile_drops_unused_scaffold_gems
    gemfile = File.read(File.join(ROOT, "test/dummy/Gemfile"))

    %w[jbuilder image_processing solid_cache solid_queue solid_cable kamal thruster].each do |name|
      refute_match(/gem ["']#{name}["']/, gemfile)
    end
  end

  def test_changelog_links_releases_without_a_031_heading
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))

    assert_includes changelog, "## [0.4.1]"
    assert_includes changelog, "compare/v0.3.1...v0.4.0"
    refute_includes changelog, "## [0.3.1]"
  end
end
