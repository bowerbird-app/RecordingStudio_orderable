# frozen_string_literal: true

require "test_helper"

class DocumentationSurfaceTest < Minitest::Test
  def test_engine_routes_define_documentation_pages
    routes_path = File.expand_path("../config/routes.rb", __dir__)
    routes_source = File.read(routes_path)

    assert_includes routes_source, 'get "setup", to: "docs#setup", as: :setup'
    assert_includes routes_source, 'get "config", to: "docs#configuration", as: :config'
    assert_includes routes_source, 'get "methods", to: "docs#methods_page", as: :methods'
    assert_includes routes_source, 'get "views", to: "docs#views_page", as: :views'
  end

  def test_docs_controller_defines_static_actions
    controller_path = File.expand_path("../app/controllers/recording_studio_orderable/docs_controller.rb", __dir__)
    controller_source = File.read(controller_path)

    assert_includes controller_source, "def setup"
    assert_includes controller_source, "def configuration"
    assert_includes controller_source, "def methods_page"
    assert_includes controller_source, "def views_page"
  end

  def test_home_and_docs_views_use_flatpack_headers_and_cards
    view_paths = [
      File.expand_path("../app/views/recording_studio_orderable/home/index.html.erb", __dir__),
      File.expand_path("../app/views/recording_studio_orderable/docs/setup.html.erb", __dir__),
      File.expand_path("../app/views/recording_studio_orderable/docs/configuration.html.erb", __dir__),
      File.expand_path("../app/views/recording_studio_orderable/docs/methods_page.html.erb", __dir__),
      File.expand_path("../app/views/recording_studio_orderable/docs/views_page.html.erb", __dir__)
    ]

    view_paths.each do |view_path|
      view_source = File.read(view_path)

      assert_includes view_source, "FlatPack::Breadcrumb::Component"
      assert_includes view_source, "FlatPack::PageTitle::Component"
      assert_includes view_source, "FlatPack::Card::Component"
    end
  end

  def test_dummy_sidebar_links_to_engine_documentation_pages
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    sidebar_source = File.read(sidebar_path)

    assert_includes sidebar_source, 'label: "Setup"'
    assert_includes sidebar_source, 'label: "Config"'
    assert_includes sidebar_source, 'label: "Methods"'
    assert_includes sidebar_source, 'label: "Views"'
    assert_includes sidebar_source, "recording_studio_orderable.setup_path"
    assert_includes sidebar_source, "recording_studio_orderable.config_path"
    assert_includes sidebar_source, "recording_studio_orderable.methods_path"
    assert_includes sidebar_source, "recording_studio_orderable.views_path"
  end
end