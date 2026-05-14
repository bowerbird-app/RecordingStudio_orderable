# frozen_string_literal: true

require "test_helper"

class DocumentationSurfaceTest < Minitest::Test
  def test_engine_routes_no_longer_define_docs_pages
    routes_path = File.expand_path("../config/routes.rb", __dir__)
    routes_source = File.read(routes_path)

    refute_includes routes_source, 'get "setup", to: "docs#setup", as: :setup'
    refute_includes routes_source, 'get "config", to: "docs#configuration", as: :config'
    refute_includes routes_source, 'get "methods", to: "docs#methods_page", as: :methods'
    refute_includes routes_source, 'get "views", to: "docs#views_page", as: :views'
  end

  def test_engine_home_view_uses_flatpack_headers_without_cards
    view_path = File.expand_path("../app/views/recording_studio_orderable/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, "FlatPack::Breadcrumb::Component"
    assert_includes view_source, "FlatPack::PageTitle::Component"
    assert_includes view_source, "Documentation and demo hub"
    refute_includes view_source, "FlatPack::Card::Component"
  end

  def test_engine_application_controller_uses_plain_application_layout
    controller_path = File.expand_path("../app/controllers/recording_studio_orderable/application_controller.rb", __dir__)
    controller_source = File.read(controller_path)

    assert_includes controller_source, 'layout :recording_studio_orderable_layout'
    assert_includes controller_source, '"application"'
    refute_includes controller_source, 'flat_pack_sidebar'
  end

  def test_dummy_routes_define_local_documentation_pages
    dummy_routes_path = File.expand_path("dummy/config/routes.rb", __dir__)
    dummy_routes_source = File.read(dummy_routes_path)

    assert_includes dummy_routes_source, 'get "docs/setup", to: "docs#setup", as: :docs_setup'
    assert_includes dummy_routes_source, 'get "docs/config", to: "docs#configuration", as: :docs_config'
    assert_includes dummy_routes_source, 'get "docs/methods", to: "docs#methods_page", as: :docs_methods'
    assert_includes dummy_routes_source, 'get "docs/views", to: "docs#views_page", as: :docs_views'
  end

  def test_dummy_sidebar_links_to_dummy_documentation_pages
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    sidebar_source = File.read(sidebar_path)

    assert_includes sidebar_source, 'label: "Setup"'
    assert_includes sidebar_source, 'label: "Config"'
    assert_includes sidebar_source, 'label: "Methods"'
    assert_includes sidebar_source, 'label: "Views"'
    assert_includes sidebar_source, "docs_setup_path"
    assert_includes sidebar_source, "docs_config_path"
    assert_includes sidebar_source, "docs_methods_path"
    assert_includes sidebar_source, "docs_views_path"
  end

  def test_dummy_docs_views_use_flatpack_headers_without_cards
    view_expectations = {
      File.expand_path("dummy/app/views/docs/setup.html.erb", __dir__) => "Install flow",
      File.expand_path("dummy/app/views/docs/configuration.html.erb", __dir__) => "Initializer example",
      File.expand_path("dummy/app/views/docs/methods_page.html.erb", __dir__) => "RecordingOrder mutations",
      File.expand_path("dummy/app/views/docs/views_page.html.erb", __dir__) => "Mounted addon pages"
    }

    view_expectations.each do |view_path, expected_content|
      view_source = File.read(view_path)

      assert_includes view_source, "FlatPack::Breadcrumb::Component"
      assert_includes view_source, "FlatPack::PageTitle::Component"
      assert_includes view_source, expected_content
      refute_includes view_source, "FlatPack::Card::Component"
    end
  end
end
