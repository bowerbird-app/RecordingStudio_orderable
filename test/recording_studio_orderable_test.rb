# frozen_string_literal: true

require "test_helper"

class RecordingStudioOrderableTest < Minitest::Test
  def test_version_exists
    refute_nil ::RecordingStudioOrderable::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioOrderable::Engine
  end

  def test_dummy_app_uses_flatpack_sidebar_layout
    layout_path = File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__)
    assert File.exist?(layout_path)

    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)
    assert_includes controller_source, "flat_pack_sidebar"
  end

  def test_recording_studio_capabilities_are_off_by_default
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "Built-in capabilities remain disabled"
    refute_includes initializer_source, "config.features."
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "Folder + Page ordering demo"
    assert_includes readme_source, "RecordingStudioOrderable"
  end

  def test_dummy_home_page_mentions_ordering_demo
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)
    helper_path = File.expand_path("dummy/app/helpers/application_helper.rb", __dir__)
    helper_source = File.read(helper_path)
    controller_path = File.expand_path("dummy/app/javascript/controllers/page_order_form_controller.js", __dir__)
    controller_source = File.read(controller_path)
    home_controller_path = File.expand_path("dummy/app/controllers/home_controller.rb", __dir__)
    home_controller_source = File.read(home_controller_path)

    assert_includes view_source, "Folder page order"
    assert_includes view_source, "Your named lists"
    assert_includes view_source, "FlatPack::Table::Component"
    assert_includes view_source, "Create new list"
    assert_includes view_source, "moving_recording_id"
    assert_includes view_source, "target_position"
    assert_includes view_source, "selected_order_recording_id"
    assert_includes helper_source, "Auto-appended eligible page"
    assert_includes controller_source, "detectSingleMove"
    assert_includes controller_source, "requestAnimationFrame"
    assert_includes home_controller_source, "named_page_order_recordings"
    assert_includes home_controller_source, "selected_page_order_recording"
  end

  def test_engine_home_page_uses_flatpack_components
    view_path = File.expand_path("../app/views/recording_studio_orderable/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, "FlatPack::PageTitle::Component"
    assert_includes view_source, "FlatPack::Card::Component"
    assert_includes view_source, "FlatPack::Badge::Component"
  end

  def test_engine_application_controller_prefers_sidebar_layout_when_available
    controller_path = File.expand_path("../app/controllers/recording_studio_orderable/application_controller.rb", __dir__)
    controller_source = File.read(controller_path)

    assert_includes controller_source, "layout :recording_studio_orderable_layout"
    assert_includes controller_source, 'return "flat_pack_sidebar" if host_sidebar_layout_available?'
    assert_includes controller_source, 'Dir.glob(Rails.root.join("app/views/layouts/flat_pack_sidebar.*")).any?'
    assert_includes controller_source, '"application"'
  end

  def test_dummy_sidebar_uses_host_app_sign_out_route
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    sidebar_source = File.read(sidebar_path)

    assert_includes sidebar_source, "main_app.destroy_user_session_path"
  end

  def test_dummy_sidebar_uses_heroicon_style_icon_names
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    sidebar_source = File.read(sidebar_path)

    assert_includes sidebar_source, "icon: :beaker"
    assert_includes sidebar_source, "icon: :wrench_screwdriver"
    assert_includes sidebar_source, "icon: :cog_6_tooth"
    assert_includes sidebar_source, "icon: :code_bracket"
    assert_includes sidebar_source, "icon: :rectangle_stack"
    assert_includes sidebar_source, "icon: :arrow_right_on_rectangle"
  end
end
