# frozen_string_literal: true

require "test_helper"

class RecordingStudioOrderableTest < Minitest::Test
  def test_version_exists
    refute_nil RecordingStudioOrderable::VERSION
  end

  def test_recording_studio_dependency_is_6_1_or_newer
    spec = Gem.loaded_specs.fetch("recording_studio")
    flat_pack = Gem.loaded_specs.fetch("flat_pack")
    view_component = Gem.loaded_specs.fetch("view_component")
    gemspec = File.read(File.expand_path("../recording_studio_orderable.gemspec", __dir__))

    assert spec.version >= Gem::Version.new("6.1.0"),
           "expected recording_studio >= 6.1.0, got #{spec.version}"
    assert flat_pack.version >= Gem::Version.new("0.1.315"),
           "expected flat_pack >= 0.1.315, got #{flat_pack.version}"
    assert view_component.version >= Gem::Version.new("4.14"),
           "expected view_component >= 4.14, got #{view_component.version}"
    assert view_component.version < Gem::Version.new("5"),
           "expected view_component < 5, got #{view_component.version}"
    assert_includes gemspec, 'spec.add_dependency "recording_studio", ">= 6.1.0"'
    assert_includes gemspec, 'spec.add_dependency "flat_pack", ">= 0.1.315"'
    assert_includes gemspec, 'spec.add_dependency "rails", "~> 8.1.0"'
    refute_includes gemspec, "recording_studio_accessible"
    assert_equal Gem::Version.new("6.3.0"), spec.version
    assert_equal Gem::Version.new("0.1.332"), flat_pack.version
    assert_equal Gem::Version.new("4.19.0"), view_component.version

    %w[Gemfile test/dummy/Gemfile].each do |relative|
      gemfile = File.read(File.expand_path("../#{relative}", __dir__))
      assert_includes gemfile, 'gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"'
      assert_includes gemfile, 'gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.332"'
      refute_includes gemfile, "1fcbafe94f8eb118f0a22182f63f5110fcc97a56"
      refute_includes gemfile, 'tag: "v6.1.0"'
    end
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

    assert_includes controller_source, "recording_studio_layout"
    refute_includes controller_source, "UsesDefaultLayout"
    refute_includes controller_source, "recording_studio/default_layout"
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/config/initializers/recording_studio_default_layout.rb", __dir__))
    assert_includes home_source, "content_for :title"
    assert_includes home_source, "flat_pack_page_nav("
    assert_includes home_source, "register_page_nav"
    refute_includes home_source, "recording_studio_page_nav("
    refute_includes home_source, "FlatPack::PageTitle::Component"
    refute_includes home_source, "Card::Component.new(style:"
    assert_includes home_source, "FlatPack::Table::Component"
    assert_includes home_source, "FlatPack::Button::Component"
    demo_nav = File.read(File.expand_path("dummy/app/views/home/_demo_nav.html.erb", __dir__))
    assert_includes demo_nav, "href: link.fetch(:href)"
    assert_includes demo_nav, "current: current_page?(link.fetch(:href))"
    refute_includes demo_nav, "url: link.fetch"
    assert_includes login_source, "admin@admin.com"
    assert_includes login_source, "FlatPack::Card::Component"
    assert_includes login_source, "background: :default"
    refute_includes login_source, "background: :shaded"
    refute_includes login_source, "style: :elevated"
    assert_includes login_source, "FlatPack::Stack::Component"
    stylesheets = File.read(File.expand_path("dummy/app/views/layouts/_flat_pack_stylesheets.html.erb", __dir__))
    variables_at = stylesheets.index("flat_pack/variables")
    tailwind_at = stylesheets.index("tailwind")
    assert variables_at && tailwind_at && variables_at < tailwind_at
    assert_includes stylesheets, "flat_pack/application"
    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(File.expand_path("..", __dir__))
    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(File.expand_path("dummy", __dir__))
  end

  def test_screens_use_flatpack_layout_and_drop_the_reorder_shim
    engine_home = File.read(File.expand_path("../app/views/recording_studio_orderable/home/index.html.erb", __dir__))
    dummy_home = File.read(File.expand_path("dummy/app/views/home/index.html.erb", __dir__))
    events = File.read(File.expand_path("dummy/app/views/events/show.html.erb", __dir__))
    login = File.read(File.expand_path("dummy/app/views/devise/sessions/new.html.erb", __dir__))
    layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes engine_home, "FlatPack::Stack::Component.new(gap: :lg)"
    assert_includes engine_home, "FlatPack::SectionTitle::Component"
    assert_includes engine_home, "FlatPack::Text::Component"
    assert_includes engine_home, "FlatPack::CodeBlock::Component"
    assert_includes engine_home, "Enable ordering"
    assert_includes engine_home, "include RecordingStudio::Capabilities::Orderable.to HOST"
    assert_includes engine_home, "Add this to the parent type whose children should be sortable."
    refute_includes engine_home, "FlatPack::Grid::Component"
    refute_includes engine_home, "flex flex-col"
    refute_includes engine_home, "<p>"
    refute_includes engine_home, "<code>"
    refute_includes engine_home, "FlatPack::PageTitle::Component"

    assert_includes dummy_home, "reorder_url: reorder_pages_path"
    assert_includes dummy_home, "justify: :between"
    assert_includes dummy_home, "order-refresh"
    assert_includes dummy_home, "flat-pack--table-sortable:saved->order-refresh#refresh"
    assert_includes dummy_home, "id: \"order-demo-table\""
    assert_includes dummy_home, "FlatPack::Shared::IconComponent.new(name: \"bars-3\""
    refute_includes dummy_home, "icon_only"
    refute_includes dummy_home, "<div id=\"order-demo-table\">"
    assert_includes dummy_home, "FlatPack::CodeBlock::Component"
    assert_includes dummy_home, "FlatPack::Cluster::Component"
    refute_includes dummy_home, "page-reorder"
    refute_includes dummy_home, "<p>"
    refute_includes dummy_home, "<code>"
    refute_includes dummy_home, "flex flex-col"
    refute_includes dummy_home, "flex flex-wrap"
    refute File.exist?(File.expand_path("dummy/app/javascript/controllers/page_reorder_controller.js", __dir__))

    assert_includes events, "FlatPack::Timestamp::Component.new"
    assert_includes events, "tooltip_placement: :top"
    refute_includes events, "button_tag"
    refute_includes events, "tag.pre"
    refute_includes events, "Popover::Component"
    assert_includes events, "FlatPack::CodeBlock::Component"
    assert_includes events, "min_width: :none"
    assert_includes events, "width: \"12rem\""
    assert_includes events, "width: \"10rem\""
    assert_includes events, "width: \"8.5rem\""
    assert_includes events, "max-w-full"
    refute_includes events, "width: \"24rem\""
    refute_includes events, "width: \"9rem\""
    assert_includes events, "wrap: :nowrap"

    refute_includes login, "space-y-4"
    refute_includes login, "mx-auto"
    refute_includes layout, "mb-6"
    refute_includes layout, "icon_sprite"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/_icon_sprite.html.erb", __dir__))
  end

  def test_dummy_tailwind_sources_scan_vendor_bundle_and_split_globs
    css = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes css, '@source "../../views/**/*.erb";'
    assert_includes css, '@source "../../../../../app/views/**/*.erb";'
    assert_includes css, '@source "../../../vendor/bundle/**/bundler/gems/flatpack-*/app/components/**/*.rb";'
    assert_includes css, '@source "../../../vendor/bundle/**/bundler/gems/flatpack-*/app/components/**/*.erb";'
    assert_includes css, '@source "../../../vendor/bundle/**/bundler/gems/RecordingStudio-*/app/views/**/*.erb";'
    assert_includes css, '@source "/usr/local/lib/ruby/gems/**/bundler/gems/flatpack-*/app/components/**/*.rb";'
    assert_includes css, '@source "/usr/local/lib/ruby/gems/**/bundler/gems/RecordingStudio-*/app/views/**/*.erb";'
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
    assert_includes readme, "allow every caller"
    assert_includes readme, "Do not call Moveable to reorder siblings"
    assert_includes readme, "Do not use Orderable move! to change parent"
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

  def test_capability_options_for_does_not_rescue_missing_api
    RecordingStudio.stub(:capability_options, ->(*) { raise NoMethodError, "missing" }) do
      assert_raises(NoMethodError) do
        RecordingStudioOrderable.capability_options_for("Folder")
      end
    end
  end

  def test_capability_options_for_accepts_string_class_recording_and_nil
    recording = Struct.new(:recordable_type).new("Folder")
    seen = []

    RecordingStudio.stub(:capability_options, lambda { |*args, **kwargs|
      seen << [args, kwargs]
      { allows: ["Page"] }
    }) do
      assert_equal({ allows: ["Page"] }, RecordingStudioOrderable.capability_options_for("Folder"))
      assert_equal({ allows: ["Page"] }, RecordingStudioOrderable.capability_options_for(FolderType))
      assert_equal({ allows: ["Page"] }, RecordingStudioOrderable.capability_options_for(recording))
      assert_equal({}, RecordingStudioOrderable.capability_options_for(nil))
    end

    assert_equal [[[:orderable], { for: "Folder" }]], seen.uniq
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
