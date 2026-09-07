# frozen_string_literal: true

require "test_helper"

class RecordingStudioOrderableTest < Minitest::Test
  def test_version_exists
    refute_nil RecordingStudioOrderable::VERSION
  end

  def test_recording_studio_dependency_is_4_1_or_newer
    spec = Gem.loaded_specs.fetch("recording_studio")
    gemspec = File.read(File.expand_path("../recording_studio_orderable.gemspec", __dir__))

    assert spec.version >= Gem::Version.new("4.1.0"),
           "expected recording_studio >= 4.1.0, got #{spec.version}"
    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.1"'
    assert_includes gemspec, 'spec.add_dependency "flat_pack", ">= 0.1.74"'
    assert_includes gemspec, 'spec.add_dependency "rails", "~> 8.1.0"'
    refute_includes gemspec, "recording_studio_accessible"
  end

  def test_version_matches_latest_changelog_release
    changelog = File.read(File.expand_path("../CHANGELOG.md", __dir__))

    assert_includes changelog, "## [#{RecordingStudioOrderable::VERSION}]"
  end

  def test_engine_exists
    assert_kind_of Class, RecordingStudioOrderable::Engine
  end

  def test_page_capability_alias_is_registered
    assert_equal RecordingStudio::Orderable::Capabilities::Orderable, RecordingStudio::Capabilities::Orderable
  end

  def test_dummy_uses_core_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    home_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    login_path = File.expand_path("dummy/app/views/devise/sessions/new.html.erb", __dir__)
    controller_source = File.read(application_controller_path)
    home_source = File.read(home_path)
    login_source = File.read(login_path)

    assert_includes controller_source, "RecordingStudio::UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    assert_includes home_source, "recording_studio_page_nav("
    assert_includes home_source, "FlatPack::PageTitle::Component"
    assert_includes home_source, "FlatPack::Table::Component"
    assert_includes home_source, "FlatPack::Button::Component"
    demo_nav = File.read(File.expand_path("dummy/app/views/home/_demo_nav.html.erb", __dir__))
    assert_includes demo_nav, "href: link.fetch(:href)"
    refute_includes demo_nav, "url: link.fetch"
    assert_includes login_source, "admin@admin.com"
    assert_includes login_source, "FlatPack::Card::Component"
    assert_includes login_source, "FlatPack::Grid::Component"
  end

  def test_dummy_tailwind_sources_scan_vendor_bundle_and_split_globs
    css = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes css, '@source "../../views/**/*.erb";'
    assert_includes css, '@source "../../../../../app/views/**/*.erb";'
    assert_includes css, '@source "../../../vendor/bundle/**/bundler/gems/flatpack-*/app/components/**/*.rb";'
    assert_includes css, '@source "../../../vendor/bundle/**/bundler/gems/flatpack-*/app/components/**/*.erb";'
    assert_includes css, '@source "../../../vendor/bundle/**/bundler/gems/RecordingStudio-*/app/views/**/*.erb";'
    refute_includes css, '@source "../../vendor/bundle'
    refute_includes css, "*.{rb,erb}"
  end

  def test_dummy_enables_orderable_only_on_folder
    folder = File.read(File.expand_path("dummy/app/models/folder.rb", __dir__))
    page = File.read(File.expand_path("dummy/app/models/page.rb", __dir__))
    project = File.read(File.expand_path("dummy/app/models/project.rb", __dir__))
    workspace = File.read(File.expand_path("dummy/app/models/workspace.rb", __dir__))

    assert_includes folder, "include RecordingStudio::Capabilities::Orderable.to"
    assert_includes folder, 'allows: [ "Page" ]'
    refute_includes page, "Orderable.to"
    refute_includes project, "Orderable.to"
    refute_includes workspace, "Orderable.to"
    refute_includes folder, "OrderableRecordable"
    refute_includes folder, "recording_studio_order_group"
  end

  def test_dummy_recordables_declare_recording_studio_hierarchy
    assert_dummy_model_includes("workspace.rb", 'recording_studio_recordable label: "Workspace"')
    assert_dummy_model_includes("workspace.rb", "root: true")
    assert_dummy_model_includes("project.rb", 'recording_studio_recordable label: "Project"')
    assert_dummy_model_includes("folder.rb", 'recording_studio_recordable label: "Folder"')
    assert_dummy_model_includes("page.rb", 'recording_studio_recordable label: "Page"')
  end

  def test_dummy_current_supports_actor_and_impersonator
    current_model = File.read(File.expand_path("dummy/app/models/current.rb", __dir__))

    assert_includes current_model, "attribute :actor, :impersonator"
  end

  def test_dummy_does_not_ship_template_docs_pages
    refute File.exist?(File.expand_path("dummy/app/views/docs/setup.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/docs/configuration.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/docs/methods_page.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/docs/views_page.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/controllers/docs_controller.rb", __dir__))
  end

  def test_dummy_readme_explains_host_purpose
    readme = File.read(File.expand_path("dummy/README.md", __dir__))

    assert_includes readme, "Recording Studio Orderable"
    assert_includes readme, "default layout"
    refute_includes readme, "gem_template"
  end

  def test_product_readme_is_not_template_copy
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "Recording Studio Orderable"
    assert_includes readme, "RecordingStudio::Capabilities::Orderable.to"
    assert_includes readme, "recording_studio_orderable_append!"
    refute_includes readme, "RecordingStudio::RecordingStudioOrder"
    refute_includes readme, "OrderableRecordable"
    refute_includes readme, "Welcome to the template"
  end

  def test_engine_does_not_register_an_order_recordable
    engine = File.read(File.expand_path("../lib/recording_studio_orderable/engine.rb", __dir__))
    models = Dir.glob(File.expand_path("../app/models/**/*.rb", __dir__))

    refute_includes engine, "register_recordable_type"
    assert_empty models
  end

  def test_capability_options_for_reads_registered_options
    RecordingStudio.stub(:capability_options, { allows: ["Page"] }) do
      assert_equal({ allows: ["Page"] }, RecordingStudioOrderable.capability_options_for("Folder"))
    end
  end

  def test_capability_options_for_handles_missing_api
    RecordingStudio.stub(:capability_options, ->(*) { raise NoMethodError }) do
      assert_equal({}, RecordingStudioOrderable.capability_options_for("Folder"))
    end
  end

  def test_capability_options_for_accepts_class_and_recording
    recording = Struct.new(:recordable_type).new("Folder")

    RecordingStudio.stub(:capability_options, ->(*args, **kwargs) { { args: args, kwargs: kwargs } }) do
      assert_equal "Folder", RecordingStudioOrderable.send(:capability_type_name, FolderType)
      assert_equal "Folder", RecordingStudioOrderable.send(:capability_type_name, :Folder)
      assert_equal "Folder", RecordingStudioOrderable.send(:capability_type_name, recording)
      assert_nil RecordingStudioOrderable.send(:capability_type_name, nil)
    end
  end

  def test_authorized_delegates_to_authorization
    called = nil
    RecordingStudioOrderable::Authorization.stub(
      :authorized?,
      lambda { |**kwargs|
        called = kwargs
        true
      }
    ) do
      assert RecordingStudioOrderable.authorized?(action: :reorder, actor: :user, recording: :rec)
    end

    assert_equal :reorder, called[:action]
    assert_equal :user, called[:actor]
    assert_equal :rec, called[:recording]
  end

  FolderType = Class.new do
    def self.name
      "Folder"
    end
  end

  private

  def assert_dummy_model_includes(filename, snippet)
    source = File.read(File.expand_path("dummy/app/models/#{filename}", __dir__))
    assert_includes source, snippet
  end
end
