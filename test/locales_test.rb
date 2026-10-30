# frozen_string_literal: true

require "test_helper"
require "yaml"
require "i18n"

class LocalesTest < Minitest::Test
  EXPECTED_LEAVES = {
    "recording_studio.orderable.home.title" => "Orderable",
    "recording_studio.orderable.home.page_nav_anchor_label" => "Home",
    "recording_studio.orderable.home.page_title" => "Recording Studio Orderable",
    "recording_studio.orderable.home.subtitle" =>
      "Opt in per recordable type. Sibling position lives on the child recording, not as a tree object.",
    "recording_studio.orderable.home.body_before" => "Enable ordering",
    "recording_studio.orderable.home.body_after" =>
      "Add this on the parent type whose children should be sortable."
  }.freeze

  def setup
    @previous_load_path = I18n.load_path.dup
    @previous_backend = I18n.backend
    @previous_locale = I18n.locale
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.load_translations(*Dir[File.join(engine_locales_dir, "*.yml")])
    I18n.locale = :en
  end

  def teardown
    I18n.backend = @previous_backend
    I18n.locale = @previous_locale
    assert_equal @previous_load_path, I18n.load_path,
                 "locales tests must not mutate I18n.load_path"
  end

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_rails_i18n_load_path_includes_the_gem_english_locale_file
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    existent = RecordingStudioOrderable::Engine.paths["config/locales"].existent.map { |path| File.expand_path(path) }

    assert_includes existent, locale_path
  end

  def test_lib_sources_do_not_append_i18n_load_path
    lib_root = File.expand_path("../lib", __dir__)
    ruby_files = Dir[File.join(lib_root, "**", "*.rb")]

    refute_empty ruby_files, "expected lib/**/*.rb files to scan"

    ruby_files.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not touch i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not touch I18n.load_path"
    end
  end

  def test_english_keys_resolve_without_missing_translations
    I18n.with_locale(:en) do
      EXPECTED_LEAVES.each do |full_key, english|
        translation = I18n.t(full_key, default: nil)

        assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
        assert_equal english, I18n.t(full_key, raise: true)
      end
    end
  end

  def test_en_yml_nests_keys_under_recording_studio_orderable
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("orderable")

    assert_equal "Orderable", tree.fetch("home").fetch("title")
    assert_equal "Recording Studio Orderable", tree.fetch("home").fetch("page_title")
    assert_equal "Enable ordering", tree.fetch("home").fetch("body_before")
  end

  def test_yes_no_on_off_locale_keys_resolve_without_default
    yes_no_keys = collect_yes_no_on_off_keys(
      locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
    )

    I18n.with_locale(:en) do
      yes_no_keys.each do |key|
        full_key = key.start_with?("recording_studio.") ? key : "recording_studio.orderable.#{key}"
        translation = I18n.t(full_key)

        refute_equal "translation missing: en.#{full_key}", translation
        refute_includes translation.to_s, "translation missing"
      end
    end
  end

  def test_home_view_passes_english_defaults_on_every_t_call
    view_source = File.read(
      File.expand_path("../app/views/recording_studio_orderable/home/index.html.erb", __dir__)
    )

    t_calls = view_source.scan(/t\(\s*["']recording_studio\.orderable\.[^"']+["'][^)]*\)/)
    refute_empty t_calls, "expected t() calls under recording_studio.orderable.*"

    t_calls.each do |call|
      assert_match(/default:\s*["']/, call, "#{call} must pass an English default:")
    end
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  def collect_yes_no_on_off_keys(tree, prefix = nil)
    keys = []
    tree.each do |key, value|
      dotted = prefix ? "#{prefix}.#{key}" : key.to_s
      if value.is_a?(Hash)
        keys.concat(collect_yes_no_on_off_keys(value, dotted))
      elsif key.to_s.match?(/\A(yes|no|on|off|true|false|null)\z/i)
        keys << dotted.sub(/\Arecording_studio\.orderable\./, "")
      end
    end
    keys
  end
end
