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

    assert_includes readme_source, "Recording Studio custom ordering demo"
    assert_includes readme_source, "RecordingStudioOrderable"
  end

  def test_dummy_home_page_mentions_ordering_demo
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)
    demo_partial_path = File.expand_path("dummy/app/views/home/_page_order_demo.html.erb", __dir__)
    demo_partial_source = File.read(demo_partial_path)
    helper_path = File.expand_path("dummy/app/helpers/application_helper.rb", __dir__)
    helper_source = File.read(helper_path)
    controller_path = File.expand_path("dummy/app/javascript/controllers/page_order_form_controller.js", __dir__)
    controller_source = File.read(controller_path)
    auto_submit_controller_path = File.expand_path("dummy/app/javascript/controllers/auto_submit_controller.js",
                                                   __dir__)
    auto_submit_controller_source = File.read(auto_submit_controller_path)
    home_controller_path = File.expand_path("dummy/app/controllers/home_controller.rb", __dir__)
    home_controller_source = File.read(home_controller_path)

    assert_includes view_source, "Order Demo Examples"
    assert_includes view_source, "Ordered List"
    assert_includes view_source, "Add new"
    assert_includes view_source, "FlatPack::Select::Component"
    assert_includes view_source, "hidden_field_tag :demo, @demo_variant"
    assert_includes view_source, 'turbo_frame_tag "page_order_demo"'
    assert_includes view_source, 'data: { turbo_frame: "page_order_demo" }'
    assert_includes view_source, 'controller: "auto-submit"'
    assert_includes view_source, 'action: "change->auto-submit#submit"'
    assert_includes view_source, 'render "page_order_demo", demo_variant: @demo_variant'
    refute_includes view_source, "select_tag :selected_order_recording_id"
    refute_includes view_source, 'onchange: "this.form.requestSubmit()"'
    refute_includes view_source, "grid gap-4 lg:grid-cols-2"
    refute_includes view_source, "link_to root_path(selected_order_recording_id: list_row.recording.id)"
    assert_includes view_source, "No ordered list yet"
    assert_includes view_source, "an ordered list now."
    assert_includes view_source, "selected_order_recording_id"
    assert_includes demo_partial_source, "FlatPack::Table::Component"
    assert_includes demo_partial_source, 'table.column(title: "", html: ->(_row) { page_order_drag_handle })'
    expected_controller_binding =
      'data-controller="<%= [("order-update-alert" if send_custom_event), "page-order-form"].compact.join(" ") %>"'
    assert_includes demo_partial_source, expected_controller_binding
    assert_includes demo_partial_source, 'data-page-order-form-send-custom-event-value="<%= send_custom_event %>"'
    assert_includes demo_partial_source, "Code Example"
    assert_includes demo_partial_source, 'data-page-order-form-target="status"'
    assert_includes helper_source, "page_order_demo_code_sample"
    assert_includes helper_source, "page_order_drag_handle"
    assert_includes helper_source, "content_tag("
    assert_includes helper_source, '"⋮⋮"'
    assert_includes helper_source, "cursor-grab"
    assert_includes helper_source, "Example 1: Custom Event"
    assert_includes helper_source, "Example 2: Flash Message"
    refute_includes view_source, "Your named lists"
    refute_includes view_source, "Each list is owner-scoped to the signed-in user"
    refute_includes view_source, "Folder page order"
    refute_includes view_source, "Eligible pages omitted from ordered_recording_ids"
    assert_includes helper_source, "Auto-appended eligible page"
    refute_includes helper_source, "flat-pack--table-sortable#moveUp"
    refute_includes helper_source, "flat-pack--table-sortable#moveDown"
    refute_includes demo_partial_source, 'table.column(title: "Move"'
    assert_includes controller_source, "detectSingleMove"
    assert_includes controller_source, "requestAnimationFrame"
    assert_includes controller_source, "fetch(this.formTarget.action"
    assert_includes controller_source, "sendCustomEventValue"
    assert_includes controller_source, "recordingstudio:order:updated"
    assert_includes controller_source, "dispatchUpdateEvent"
    assert_includes controller_source, "visitRedirect"
    assert_includes controller_source, "window.Turbo?.visit"
    assert_includes controller_source, "restoreRowOrder"
    assert_includes controller_source, "updateDisplayedPositions"
    assert_includes controller_source, 'querySelector("[data-page-order-position]")'
    refute_includes controller_source, 'querySelector("td")'
    order_update_alert_controller_path = File.expand_path(
      "dummy/app/javascript/controllers/order_update_alert_controller.js", __dir__
    )
    order_update_alert_controller_source = File.read(order_update_alert_controller_path)
    assert_includes order_update_alert_controller_source, "recordingstudio:order:updated"
    assert_includes order_update_alert_controller_source, "console.log(message)"
    assert_includes auto_submit_controller_source, "requestSubmit"
    assert_includes auto_submit_controller_source, "event.target.form"
    assert_includes home_controller_source, "named_page_order_recordings"
    assert_includes home_controller_source, "selected_page_order_recording"
    assert_includes home_controller_source, "DEFAULT_DEMO_VARIANT = \"custom_event\""
    assert_includes home_controller_source, "load_demo_variant"
    assert_includes home_controller_source, "page_order_demo_path"
    refute_includes home_controller_source, "ListRow"
    refute_includes home_controller_source, "@list_rows"
    assert_includes home_controller_source, 'CUSTOM_EVENT_NAME = "recordingstudio:order:updated"'
    assert_includes home_controller_source, "send_custom_event_param?"
    assert_includes home_controller_source, "redirect_url:"
    refute_includes home_controller_source, "render_to_string("
    refute_includes home_controller_source, "notice_html:"
    assert_includes home_controller_source, "render json: { error:"
  end

  def test_engine_home_page_uses_flatpack_components
    view_path = File.expand_path("../app/views/recording_studio_orderable/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, "FlatPack::PageTitle::Component"
    assert_includes view_source, "FlatPack::Badge::Component"
    assert_includes view_source, "Documentation and demo hub"
    assert_includes view_source, "mounted pages link directly between the home page"
    refute_includes view_source, "FlatPack::Card::Component"
    refute_includes view_source, "dummy app sidebar"
  end

  def test_engine_application_controller_prefers_sidebar_layout_when_available
    controller_path = File.expand_path(
      "../app/controllers/recording_studio_orderable/application_controller.rb",
      __dir__
    )
    controller_source = File.read(controller_path)

    assert_includes controller_source, "layout :recording_studio_orderable_layout"
    assert_includes controller_source, '"application"'
    refute_includes controller_source, "flat_pack_sidebar"
  end

  def test_engine_new_order_list_page_uses_back_only_breadcrumb
    view_path = File.expand_path("../app/views/recording_studio_orderable/recording_studio_orders/new.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, "FlatPack::Breadcrumb::Component"
    assert_includes view_source, "show_back: true"
    assert_includes view_source, 'back_href: "javascript:window.history.back()"'
    assert_includes view_source, "@parent_recording_label"
    refute_includes view_source, "show_home: true"
    refute_includes view_source, "home_url: main_app.root_path"
    refute_includes view_source, 'breadcrumb.item(text: "Create ordered list")'
    refute_includes view_source, "Save a new order list for this recording."
  end

  def test_dummy_sidebar_uses_host_app_sign_out_route
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    sidebar_source = File.read(sidebar_path)

    assert_includes sidebar_source, "main_app.destroy_user_session_path"
  end

  def test_dummy_sidebar_uses_heroicon_style_icon_names
    sidebar_path = File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__)
    sidebar_source = File.read(sidebar_path)

    assert_includes sidebar_source, "Drag & Drop: Custom Event"
    assert_includes sidebar_source, "Drag & Drop: Flash Message"
    assert_includes sidebar_source, 'main_app.root_path(demo: "custom_event")'
    assert_includes sidebar_source, 'main_app.root_path(demo: "flash_message")'
    assert_includes sidebar_source, "icon: :arrows_up_down"
    assert_includes sidebar_source, "icon: :bell_alert"
    assert_includes sidebar_source, "icon: :wrench_screwdriver"
    assert_includes sidebar_source, "icon: :cog_6_tooth"
    assert_includes sidebar_source, "icon: :code_bracket"
    assert_includes sidebar_source, "icon: :rectangle_stack"
    assert_includes sidebar_source, "icon: :arrow_right_on_rectangle"
  end
end
