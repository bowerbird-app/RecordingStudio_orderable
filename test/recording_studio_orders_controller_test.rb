# frozen_string_literal: true

def test_load_show_context_sets_single_order_and_renders_show_order
  RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
  @controller.params_hash = { parent_recording_id: "parent-1", id: "order-1" }
  parent_recording = build_parent_recording_with_groups({
                                                          "pages" => { group_key: "pages", allows: ["Page"] }
                                                        })
  order_recordable = Struct.new(:name).new("Homepage")
  named_order_recording = Struct.new(:id, :recordable, :created_at, :updated_at).new("order-1", order_recordable,
                                                                                     Time.now, Time.now)

  with_temporary_recording_class do |recording_class|
    recording_class.define_singleton_method(:find) { |_id| parent_recording }
    RecordingStudioOrderable::RecordingOrderManager.stub(
      :recording_order_recordings,
      [named_order_recording]
    ) do
      @controller.send(:load_show_context)
      assert_equal "order-1", @controller.instance_variable_get(:@single_order).id
      assert_equal "Homepage", @controller.send(:order_display_name, order_recordable)
    end
  end
end
$LOAD_PATH.unshift File.expand_path(".", __dir__)
$LOAD_PATH.unshift File.expand_path("../", __dir__)
require "test_helper"
require "action_controller"
require File.expand_path("test_helper", __dir__)
require_relative "../app/controllers/recording_studio_orderable/application_controller"
require_relative "../app/controllers/recording_studio_orderable/recording_studio_orders_controller"

class RecordingStudioOrdersControllerTest < Minitest::Test
  ParentRecording = Struct.new(:id, :recordable, :recordable_type)
  Recordable = Struct.new(:name, :title)

  class ControllerDouble < RecordingStudioOrderable::RecordingStudioOrdersController
    attr_accessor :params_hash, :redirected_to, :flash_payload, :rendered_template

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def redirect_to(target, options = {})
      self.redirected_to = target
      self.flash_payload = options
    end

    def root_path
      "/"
    end

    def render(template = nil, *_args)
      self.rendered_template = template
    end

    def performed?
      redirected_to.present?
    end
  end

  def setup
    @original_configuration = RecordingStudioOrderable.instance_variable_get(:@configuration)
    RecordingStudioOrderable.instance_variable_set(:@configuration, RecordingStudioOrderable::Configuration.new)
    @controller = ControllerDouble.new
    @parent_recording = ParentRecording.new("parent-1", Recordable.new("Folder", nil), "Folder")
  end

  def teardown
    RecordingStudioOrderable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_load_form_context_denies_access_without_authorization_hook
    @controller.params_hash = { parent_recording_id: "parent-1", group_key: "pages" }
    parent_recording = @parent_recording

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      @controller.send(:load_form_context)
    end

    assert_equal "/", @controller.redirected_to
    assert_equal "You are not allowed to access that recording order.", @controller.flash_payload[:alert]
  end

  def test_load_form_context_sets_context_when_authorization_hook_allows_access
    hook_arguments = nil
    RecordingStudioOrderable.configuration.authorize_parent_recording = lambda do |controller, parent_recording|
      hook_arguments = [controller, parent_recording]
      true
    end
    @controller.params_hash = {
      parent_recording_id: "parent-1",
      group_key: "pages",
      redirect_to: "/workspace",
      source_order_recording_id: "order-1"
    }
    parent_recording = @parent_recording

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(:resolve_group_key!, "pages") do
        @controller.send(:load_form_context)
      end
    end

    assert_nil @controller.redirected_to
    assert_equal [@controller, @parent_recording], hook_arguments
    assert_equal @parent_recording, @controller.instance_variable_get(:@parent_recording)
    assert_equal "pages", @controller.instance_variable_get(:@group_key)
    assert_equal "Folder Folder", @controller.instance_variable_get(:@parent_recording_label)
    assert_equal "/workspace", @controller.instance_variable_get(:@redirect_to)
    assert_equal "order-1", @controller.instance_variable_get(:@source_order_recording_id)
  end

  def test_load_form_context_keeps_redirect_nil_when_no_redirect_or_recordable_type
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    @controller.params_hash = {
      parent_recording_id: "parent-1",
      group_key: "pages"
    }
    parent_recording = @parent_recording

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(:resolve_group_key!, "pages") do
        @controller.send(:load_form_context)
      end
    end

    assert_nil @controller.instance_variable_get(:@redirect_to)
  end

  def test_authenticate_request_calls_configured_hook
    authenticated = false
    RecordingStudioOrderable.configuration.authenticate_controller = lambda do |controller|
      authenticated = controller.equal?(@controller)
    end
    fake_configuration = Struct.new(:actor).new(-> { :actor_owner })

    RecordingStudio.stub(:configuration, fake_configuration) do
      @controller.send(:authenticate_recording_studio_orderable_request!)
    end

    assert_equal true, authenticated
  end

  def test_authenticate_request_falls_back_to_recording_studio_actor_when_hook_is_unset
    RecordingStudioOrderable.configuration.authenticate_controller = nil
    fake_configuration = Struct.new(:actor).new(-> { :actor_owner })

    RecordingStudio.stub(:configuration, fake_configuration) do
      @controller.send(:authenticate_recording_studio_orderable_request!)
    end

    assert_nil @controller.redirected_to
  end

  def test_authenticate_request_redirects_when_recording_studio_actor_is_missing
    RecordingStudioOrderable.configuration.authenticate_controller = nil
    fake_configuration = Struct.new(:actor).new(nil)

    RecordingStudio.stub(:configuration, fake_configuration) do
      @controller.send(:authenticate_recording_studio_orderable_request!)
    end

    assert_equal "/", @controller.redirected_to
    assert_equal "Authentication is required.", @controller.flash_payload[:alert]
  end

  def test_authenticate_request_skips_configured_hook_when_actor_auth_fails
    authenticated = false
    RecordingStudioOrderable.configuration.authenticate_controller = lambda do |_controller|
      authenticated = true
    end
    fake_configuration = Struct.new(:actor).new(nil)

    RecordingStudio.stub(:configuration, fake_configuration) do
      @controller.send(:authenticate_recording_studio_orderable_request!)
    end

    assert_equal false, authenticated
    assert_equal "/", @controller.redirected_to
    assert_equal "Authentication is required.", @controller.flash_payload[:alert]
  end

  def test_authenticate_request_syncs_current_actor_from_current_user_when_possible
    RecordingStudioOrderable.configuration.authenticate_controller = nil
    owner = Struct.new(:id).new("user-1")
    created_current_class = false

    unless defined?(Current)
      current_class = Class.new do
        class << self
          attr_accessor :actor
        end
      end
      Object.const_set(:Current, current_class)
      created_current_class = true
    end

    fake_configuration = Struct.new(:actor).new(-> { Current.actor })
    original_actor = Current.actor

    @controller.define_singleton_method(:current_user) { owner }

    Current.actor = nil

    RecordingStudio.stub(:configuration, fake_configuration) do
      @controller.send(:authenticate_recording_studio_orderable_request!)
    end

    assert_nil @controller.redirected_to
    assert_equal owner, Current.actor
  ensure
    Current.actor = original_actor if defined?(Current) && Current.respond_to?(:actor=)
    Object.send(:remove_const, :Current) if created_current_class && defined?(Current)
  end

  def test_current_owner_resolver_and_owner_guard_use_configured_owner
    RecordingStudioOrderable.configuration.current_owner_resolver = ->(_controller) { :owner }

    assert_equal :owner, @controller.send(:current_recording_studio_orderable_owner)

    @controller.send(:ensure_current_recording_studio_orderable_owner!)

    assert_nil @controller.redirected_to
  end

  def test_current_owner_resolver_falls_back_to_recording_studio_actor
    RecordingStudioOrderable.configuration.current_owner_resolver = nil

    fake_configuration = Struct.new(:actor).new(-> { :actor_owner })

    RecordingStudio.stub(:configuration, fake_configuration) do
      assert_equal :actor_owner, @controller.send(:current_recording_studio_orderable_owner)
    end
  end

  def test_current_owner_resolver_returns_nil_when_recording_studio_actor_missing
    RecordingStudioOrderable.configuration.current_owner_resolver = nil

    fake_configuration = Struct.new(:actor).new(nil)

    RecordingStudio.stub(:configuration, fake_configuration) do
      assert_nil @controller.send(:current_recording_studio_orderable_owner)
    end
  end

  def test_current_owner_resolver_falls_back_to_current_user_when_actor_is_missing
    RecordingStudioOrderable.configuration.current_owner_resolver = nil
    owner = Struct.new(:id).new("user-1")
    fake_configuration = Struct.new(:actor).new(nil)

    @controller.define_singleton_method(:current_user) { owner }

    RecordingStudio.stub(:configuration, fake_configuration) do
      assert_equal owner, @controller.send(:current_recording_studio_orderable_owner)
    end
  end

  def test_current_owner_resolver_falls_back_when_configured_hook_returns_nil
    owner = Struct.new(:id).new("user-2")
    fake_configuration = Struct.new(:actor).new(nil)

    RecordingStudioOrderable.configuration.current_owner_resolver = ->(_controller) {}
    @controller.define_singleton_method(:current_user) { owner }

    RecordingStudio.stub(:configuration, fake_configuration) do
      assert_equal owner, @controller.send(:current_recording_studio_orderable_owner)
    end
  end

  def test_safe_local_redirect_target_accepts_local_path_and_rejects_external_url
    assert_equal "/orders", @controller.send(:safe_local_redirect_target, "/orders")
    assert_nil @controller.send(:safe_local_redirect_target, "https://example.com/orders")
  end

  def test_append_query_param_handles_existing_query_and_blank_values
    assert_equal "/orders?a=1", @controller.send(:append_query_param, "/orders", :a, 1)
    assert_equal "/orders?a=1&b=2", @controller.send(:append_query_param, "/orders?a=1", :b, 2)
    assert_equal "/orders", @controller.send(:append_query_param, "/orders", :a, nil)
  end

  def test_create_uses_generic_alert_for_invalid_input_failures
    @controller.params_hash = { redirect_to: "/return" }
    @controller.define_singleton_method(:create_named_recording_order) do
      raise ArgumentError, "internal details should not leak"
    end

    @controller.create

    assert_equal "/return", @controller.redirected_to
    assert_equal "Unable to create that recording studio order.", @controller.flash_payload[:alert]
  end

  def test_show_renders_show_order_when_single_order_is_present
    single_order = Struct.new(:recordable).new(Struct.new(:name).new("Pinned"))
    @controller.instance_variable_set(:@single_order, single_order)

    @controller.show

    assert_equal :show_order, @controller.rendered_template
    assert_equal "Pinned", @controller.instance_variable_get(:@order_display_name)
  end

  def test_show_renders_show_when_single_order_is_missing
    @controller.instance_variable_set(:@single_order, nil)

    @controller.show

    assert_equal :show, @controller.rendered_template
  end

  def test_create_redirects_with_notice_when_order_is_created
    created_at = Time.utc(2024, 1, 2)
    order = Struct.new(:recordings).new([
                                          Struct.new(:id, :created_at).new("order-recording-1", created_at)
                                        ])
    @controller.params_hash = { redirect_to: "/return" }
    @controller.define_singleton_method(:create_named_recording_order) { order }

    @controller.create

    assert_equal "/return?selected_order_recording_id=order-recording-1", @controller.redirected_to
    assert_equal "Created order.", @controller.flash_payload[:notice]
  end

  def test_create_redirects_to_show_page_when_redirect_to_is_missing
    created_at = Time.utc(2024, 1, 2)
    order = Struct.new(:recordings).new([
                                          Struct.new(:id, :created_at).new("order-recording-1", created_at)
                                        ])
    @controller.params_hash = {
      parent_recording_id: "parent-1",
      group_key: "pages"
    }
    parent_recording = @parent_recording
    @controller.define_singleton_method(:create_named_recording_order) { order }
    @controller.define_singleton_method(:parent_recording_from_params) { parent_recording }
    @controller.define_singleton_method(:recording_studio_order_path) do |recordable_type, parent_recording_id:|
      "/recording_studio_orders/#{recordable_type}?parent_recording_id=#{parent_recording_id}"
    end

    RecordingStudioOrderable::RecordingOrderManager.stub(
      :resolve_group_definition!,
      { group_key: "pages", allows: ["Page"] }
    ) do
      @controller.create
    end

    expected_redirect = [
      "/recording_studio_orders/Page?parent_recording_id=parent-1",
      "selected_order_recording_id=order-recording-1"
    ].join("&")

    assert_equal expected_redirect,
                 @controller.redirected_to
    assert_equal "Created order.", @controller.flash_payload[:notice]
  end

  def test_create_redirects_when_parent_recording_is_missing
    @controller.params_hash = {}
    @controller.define_singleton_method(:create_named_recording_order) do
      raise ActiveRecord::RecordNotFound, "missing"
    end

    @controller.create

    assert_equal "/", @controller.redirected_to
    assert_equal "Parent recording not found.", @controller.flash_payload[:alert]
  end

  def test_create_redirect_target_returns_nil_when_default_target_cannot_be_resolved
    @controller.params_hash = { parent_recording_id: "missing", group_key: "pages" }
    order = Struct.new(:recordings).new([])
    @controller.define_singleton_method(:parent_recording_from_params) do
      raise ActiveRecord::RecordNotFound, "missing"
    end

    assert_nil @controller.send(:create_redirect_target, order)
  end

  def test_load_form_context_uses_generic_alert_for_configuration_failures
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    @controller.params_hash = { parent_recording_id: "parent-1", group_key: "pages" }
    parent_recording = @parent_recording

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(
        :resolve_group_key!,
        ->(*_args) { raise RecordingStudioOrderable::RecordingOrderManager::ConfigurationError, "secret config" }
      ) do
        @controller.send(:load_form_context)
      end
    end

    assert_equal "/", @controller.redirected_to
    assert_equal "Unable to load that recording studio order form.", @controller.flash_payload[:alert]
  end

  def test_named_order_count_for_sums_rows_across_group_definitions
    parent_recording = @parent_recording

    @controller.stub(:order_group_definitions_for, {
                       "pages" => { group_key: "pages" },
                       "notes" => { group_key: "notes" }
                     }) do
      @controller.stub(:named_order_rows_for, lambda { |_parent, group_key|
        group_key == "pages" ? [1, 2] : [3]
      }) do
        assert_equal 3, @controller.send(:named_order_count_for, parent_recording)
      end
    end
  end

  def test_type_row_for_returns_matching_row
    parent_recording = @parent_recording
    row = RecordingStudioOrderable::RecordingStudioOrdersController::TypeRow.new(
      recordable_type: "Page",
      group_key: "pages",
      custom_orders_count: 0,
      parent_recording_id: parent_recording.id
    )

    @controller.stub(:recording_type_rows, [row]) do
      result = @controller.send(:type_row_for!, parent_recording, "Page")
      assert_same row, result
    end
  end

  def test_default_group_key_for_reads_first_group_key
    parent_recording = @parent_recording

    @controller.stub(:order_group_definitions_for, {
                       "pages" => { group_key: "pages" }
                     }) do
      assert_equal "pages", @controller.send(:default_group_key_for, parent_recording)
    end
  end

  def test_order_group_definitions_for_raises_when_recordable_class_is_missing
    parent_recording = ParentRecording.new("parent-2", nil, "Missing::Type")

    assert_raises(RecordingStudioOrderable::RecordingOrderManager::ConfigurationError) do
      @controller.send(:order_group_definitions_for, parent_recording)
    end
  end

  def test_order_group_definitions_for_supports_legacy_group_definition_method
    klass = Class.new do
      def self.recording_studio_order_group_definition
        singleton_class.define_method(:recording_studio_order_group_definitions) do
          {
            "pages" => {
              group_key: "pages",
              allows: ["Page"]
            }
          }
        end
      end
    end

    parent_recording = ParentRecording.new("parent-3", klass.new, "LegacyType")

    result = @controller.send(:order_group_definitions_for, parent_recording)
    assert_equal "pages", result.fetch("pages").fetch(:group_key)
  end

  def test_load_form_context_redirects_when_parent_recording_is_missing
    @controller.params_hash = { parent_recording_id: "missing", group_key: "pages" }

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) do |_id|
        raise ActiveRecord::RecordNotFound, "missing"
      end
      @controller.send(:load_form_context)
    end

    assert_equal "/", @controller.redirected_to
    assert_equal "Parent recording not found.", @controller.flash_payload[:alert]
  end

  def test_create_named_recording_order_passes_expected_context_to_manager
    owner = Struct.new(:id).new("owner-1")
    captured = nil
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    RecordingStudioOrderable.configuration.current_owner_resolver = ->(_controller) { owner }
    @controller.params_hash = {
      parent_recording_id: "parent-1",
      group_key: "pages",
      source_order_recording_id: "source-order",
      recording_studio_order: { name: "Saved order" }
    }
    parent_recording = @parent_recording

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(:resolve_group_key!, "pages") do
        RecordingStudioOrderable::RecordingOrderManager.stub(
          :create_named_recording_order!,
          lambda do |*args, **kwargs|
            captured = { args: args, kwargs: kwargs }
            :created_order
          end
        ) do
          assert_equal :created_order, @controller.send(:create_named_recording_order)
        end
      end
    end

    assert_equal [@parent_recording, "pages"], captured[:args]
    assert_equal "Saved order", captured[:kwargs][:name]
    assert_same owner, captured[:kwargs][:owner]
    assert_same owner, captured[:kwargs][:actor]
    assert_equal({ source: "recording_studio_orderable.recording_studio_orders#create" },
                 captured[:kwargs][:metadata])
    assert_equal "source-order", captured[:kwargs][:source_order_recording_id]
  end

  def test_load_index_context_builds_type_rows_from_group_definitions
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    @controller.params_hash = { parent_recording_id: "parent-1" }
    parent_recording = build_parent_recording_with_groups({
                                                            "pages" => { group_key: "pages", allows: ["Page"] },
                                                            "assets" => { group_key: "assets", allows: ["Asset"] }
                                                          })

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(
        :recording_order_recordings,
        lambda do |_recording, group_key, owner:, named_only:, orderable_name: nil|
          assert_nil owner
          assert_equal true, named_only
          assert_nil orderable_name
          group_key == "pages" ? [Struct.new(:id, :recordable).new("order-1", Struct.new(:name).new("Alpha"))] : []
        end
      ) do
        @controller.send(:load_index_context)
      end
    end

    rows = @controller.instance_variable_get(:@type_rows)

    assert_nil @controller.redirected_to
    assert_equal %w[Asset Page], rows.map(&:recordable_type)
    assert_equal [0, 1], rows.map(&:custom_orders_count)
  end

  def test_load_index_context_without_parent_recording_id_builds_global_type_rows
    parent_recording_one = build_parent_recording_with_groups({
                                                                "pages" => { group_key: "pages", allows: ["Page"] }
                                                              },
                                                              id: "parent-1",
                                                              recordable_type: "Folder")
    parent_recording_two = build_parent_recording_with_groups({
                                                                "pages" => { group_key: "pages", allows: ["Page"] }
                                                              },
                                                              id: "parent-2",
                                                              recordable_type: "Folder")
    non_orderable_recording = ParentRecording.new(
      "ignored-order",
      Recordable.new("Order", nil),
      "RecordingStudio::RecordingStudioOrder"
    )

    @controller.params_hash = {}

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:all) do
        [parent_recording_one, parent_recording_two, non_orderable_recording]
      end
      RecordingStudioOrderable::RecordingOrderManager.stub(
        :recording_order_recordings,
        lambda do |recording, _group_key, owner:, named_only:, orderable_name: nil|
          assert_nil owner
          assert_equal true, named_only
          assert_nil orderable_name
          if recording.id == "parent-1"
            [Struct.new(:id, :recordable).new("order-1",
                                              Struct.new(:name).new("Alpha"))]
          else
            []
          end
        end
      ) do
        @controller.send(:load_index_context)
      end
    end

    rows = @controller.instance_variable_get(:@type_rows)

    assert_nil @controller.redirected_to
    assert_equal 1, rows.size
    assert_equal "Page", rows.first.recordable_type
    assert_equal "pages", rows.first.group_key
    assert_equal 1, rows.first.custom_orders_count
    assert_equal "parent-1", rows.first.parent_recording_id
  end

  def test_load_show_context_sets_type_row_and_named_order_rows
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    @controller.params_hash = { parent_recording_id: "parent-1", id: "Page" }
    parent_recording = build_parent_recording_with_groups({
                                                            "pages" => { group_key: "pages", allows: ["Page"] }
                                                          })
    named_order_recording = Struct.new(:id, :recordable).new("order-1", Struct.new(:name).new("Homepage"))

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(:recording_order_recordings,
                                                           [named_order_recording]) do
        @controller.send(:load_show_context)
      end
    end

    type_row = @controller.instance_variable_get(:@type_row)
    named_rows = @controller.instance_variable_get(:@named_order_rows)

    assert_nil @controller.redirected_to
    assert_equal "Page", type_row.recordable_type
    assert_equal "pages", type_row.group_key
    assert_equal ["Homepage"], named_rows.map(&:name)
    assert_equal ["order-1"], named_rows.map(&:recording_id)
  end

  def test_load_index_context_redirects_when_parent_recording_is_missing
    @controller.params_hash = { parent_recording_id: "missing" }

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) do |_id|
        raise ActiveRecord::RecordNotFound, "missing"
      end
      @controller.send(:load_index_context)
    end

    assert_equal "/", @controller.redirected_to
    assert_equal "Parent recording not found.", @controller.flash_payload[:alert]
  end

  def test_load_show_context_uses_generic_alert_for_unknown_type
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    @controller.params_hash = { parent_recording_id: "parent-1", id: "Unknown" }
    parent_recording = build_parent_recording_with_groups({
                                                            "pages" => { group_key: "pages", allows: ["Page"] }
                                                          })

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      @controller.send(:load_show_context)
    end

    assert_equal "/", @controller.redirected_to
    assert_equal "Unable to load recording studio orders.", @controller.flash_payload[:alert]
  end

  def test_load_form_context_uses_edit_route_defaults_for_source_and_redirect
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    @controller.params_hash = {
      id: "order-recording-1",
      parent_recording_id: "parent-1",
      group_key: "pages",
      recordable_type: "Page"
    }
    @controller.define_singleton_method(:action_name) { "edit" }
    @controller.define_singleton_method(:recording_studio_order_path) do |recordable_type, parent_recording_id:|
      "/recording_studio_orders/#{recordable_type}?parent_recording_id=#{parent_recording_id}"
    end
    parent_recording = build_parent_recording_with_groups({
                                                            "pages" => { group_key: "pages", allows: ["Page"] }
                                                          })

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(:resolve_group_key!, "pages") do
        @controller.send(:load_form_context)
      end
    end

    assert_nil @controller.redirected_to
    assert_equal "order-recording-1", @controller.instance_variable_get(:@source_order_recording_id)
    assert_equal "/recording_studio_orders/Page?parent_recording_id=parent-1",
                 @controller.instance_variable_get(:@redirect_to)
  end

  def test_load_edit_context_sets_source_order_and_ordered_record_rows
    owner = Struct.new(:id).new("owner-1")
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    RecordingStudioOrderable.configuration.current_owner_resolver = ->(_controller) { owner }
    @controller.params_hash = {
      id: "order-recording-1",
      parent_recording_id: "parent-1",
      group_key: "pages",
      recordable_type: "Page"
    }
    @controller.define_singleton_method(:recording_studio_order_path) do |recordable_type, parent_recording_id:|
      "/recording_studio_orders/#{recordable_type}?parent_recording_id=#{parent_recording_id}"
    end
    parent_recording = build_parent_recording_with_groups({
                                                            "pages" => { group_key: "pages", allows: ["Page"] }
                                                          })
    source_order = Struct.new(:name) do
      def ordered_child_recordings(owner:)
        raise "unexpected owner" unless owner.id == "owner-1"

        [
          Struct.new(:id, :recordable_type, :recordable).new("child-1", "Page", Struct.new(:title).new("Page One")),
          Struct.new(:id, :recordable_type, :recordable).new("child-2", "Page", Struct.new(:title).new("Page Two"))
        ]
      end
    end.new("Primary")
    source_order_recording = Struct.new(:id, :recordable).new("order-recording-1", source_order)

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(:resolve_group_key!, "pages") do
        @controller.send(:load_form_context)
      end
      RecordingStudioOrderable::RecordingOrderManager.stub(:recording_order_recordings,
                                                           [source_order_recording]) do
        @controller.send(:load_edit_context)
      end
    end

    rows = @controller.instance_variable_get(:@ordered_record_rows)

    assert_equal "Primary", @controller.instance_variable_get(:@source_order_name)
    assert_equal [1, 2], rows.map(&:position)
    assert_equal %w[child-1 child-2], rows.map(&:recording_id)
    assert_equal %w[Page Page], rows.map(&:recordable_type)
    assert_equal ["Page One", "Page Two"], rows.map(&:display_name)
  end

  def test_load_edit_context_redirects_when_source_order_recording_is_missing
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    @controller.params_hash = {
      id: "order-recording-1",
      parent_recording_id: "parent-1",
      group_key: "pages",
      recordable_type: "Page"
    }
    @controller.define_singleton_method(:recording_studio_order_path) do |recordable_type, parent_recording_id:|
      "/recording_studio_orders/#{recordable_type}?parent_recording_id=#{parent_recording_id}"
    end
    parent_recording = build_parent_recording_with_groups({
                                                            "pages" => { group_key: "pages", allows: ["Page"] }
                                                          })

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(:resolve_group_key!, "pages") do
        @controller.send(:load_form_context)
      end
      RecordingStudioOrderable::RecordingOrderManager.stub(:recording_order_recordings, []) do
        @controller.send(:load_edit_context)
      end
    end

    assert_equal "/", @controller.redirected_to
    assert_equal "Parent recording not found.", @controller.flash_payload[:alert]
  end

  def test_form_redirect_target_returns_nil_when_route_generation_fails
    parent_recording = @parent_recording
    @controller.params_hash = { recordable_type: "Page" }
    @controller.define_singleton_method(:recording_studio_order_path) do |_recordable_type, parent_recording_id:|
      raise ActionController::UrlGenerationError, "missing route for #{parent_recording_id}"
    end

    assert_nil @controller.send(:form_redirect_target, parent_recording)
  end

  def test_source_order_recording_id_from_params_returns_nil_when_missing
    @controller.params_hash = {}

    assert_nil @controller.send(:source_order_recording_id_from_params)
  end

  def test_load_form_context_redirects_with_alert_when_group_is_invalid
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    @controller.params_hash = {
      id: "order-recording-1",
      parent_recording_id: "parent-1",
      group_key: "invalid",
      recordable_type: "Page"
    }
    parent_recording = build_parent_recording_with_groups({
                                                            "pages" => { group_key: "pages", allows: ["Page"] }
                                                          })

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(
        :resolve_group_key!,
        ->(*_args) { raise RecordingStudioOrderable::RecordingOrderManager::ConfigurationError, "invalid group" }
      ) do
        @controller.send(:load_form_context)
      end
    end

    assert_equal "/", @controller.redirected_to
    assert_equal "Unable to load that recording studio order form.", @controller.flash_payload[:alert]
  end

  def test_edit_renders_edit_template
    @controller.edit

    assert_equal :edit, @controller.rendered_template
  end

  def test_update_redirects_to_edit_after_drag_move
    owner = Struct.new(:id).new("owner-1")
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    RecordingStudioOrderable.configuration.current_owner_resolver = ->(_controller) { owner }
    @controller.params_hash = {
      id: "order-recording-1",
      parent_recording_id: "parent-1",
      group_key: "pages",
      recordable_type: "Page",
      moving_recording_id: "child-2",
      target_position: "0"
    }
    @controller.define_singleton_method(:recording_studio_order_path) do |recordable_type, parent_recording_id:|
      "/recording_studio_orders/#{recordable_type}?parent_recording_id=#{parent_recording_id}"
    end
    @controller.define_singleton_method(:edit_recording_studio_order_path) do |id,
                                                                               parent_recording_id:,
                                                                               group_key:,
                                                                               recordable_type:|
      "/recording_studio_orders/#{id}/edit?parent_recording_id=#{parent_recording_id}" \
        "&group_key=#{group_key}&recordable_type=#{recordable_type}"
    end
    parent_recording = build_parent_recording_with_groups({
                                                            "pages" => { group_key: "pages", allows: ["Page"] }
                                                          })
    updated_recording = Struct.new(:id, :updated_at, :created_at).new("order-recording-2", Time.now, Time.now)
    updated_order = Struct.new(:recordings).new([updated_recording])
    source_order = Struct.new(:moved_to).new(nil)
    source_order.define_singleton_method(:move_to_position!) do |moving:, position:, actor:, metadata:|
      raise "unexpected move id" unless moving == "child-2"
      raise "unexpected position" unless position.zero?
      raise "unexpected actor" unless actor.id == "owner-1"
      unless metadata[:source] == "recording_studio_orderable.recording_studio_orders#update"
        raise "unexpected metadata"
      end

      updated_order
    end
    source_order_recording = Struct.new(:id, :recordable).new("order-recording-1", source_order)
    @controller.instance_variable_set(:@parent_recording, parent_recording)
    @controller.instance_variable_set(:@group_key, "pages")
    @controller.instance_variable_set(:@source_order_recording_id, "order-recording-1")

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(:resolve_group_key!, "pages") do
        RecordingStudioOrderable::RecordingOrderManager.stub(:recording_order_recordings,
                                                             [source_order_recording]) do
          @controller.update
        end
      end
    end

    expected_redirect = [
      "/recording_studio_orders/order-recording-2/edit?parent_recording_id=parent-1",
      "group_key=pages",
      "recordable_type=Page"
    ].join("&")

    assert_equal expected_redirect,
                 @controller.redirected_to
    assert_equal "Saved order.", @controller.flash_payload[:notice]
  end

  def test_update_redirects_to_root_when_named_list_missing
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    @controller.params_hash = {
      id: "order-recording-1",
      parent_recording_id: "parent-1",
      group_key: "pages",
      recordable_type: "Page",
      moving_recording_id: "child-2",
      target_position: "0"
    }
    @controller.define_singleton_method(:recording_studio_order_path) do |recordable_type, parent_recording_id:|
      "/recording_studio_orders/#{recordable_type}?parent_recording_id=#{parent_recording_id}"
    end
    parent_recording = build_parent_recording_with_groups({
                                                            "pages" => { group_key: "pages", allows: ["Page"] }
                                                          })
    @controller.instance_variable_set(:@parent_recording, parent_recording)
    @controller.instance_variable_set(:@group_key, "pages")
    @controller.instance_variable_set(:@source_order_recording_id, "order-recording-1")

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      RecordingStudioOrderable::RecordingOrderManager.stub(:resolve_group_key!, "pages") do
        RecordingStudioOrderable::RecordingOrderManager.stub(:recording_order_recordings, []) do
          @controller.update
        end
      end
    end

    assert_equal "/", @controller.redirected_to
    assert_equal "Named list not found.", @controller.flash_payload[:alert]
  end

  def test_authorize_parent_recording_from_params_redirects_when_parent_missing
    @controller.params_hash = { parent_recording_id: "missing" }

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) do |_id|
        raise ActiveRecord::RecordNotFound, "missing"
      end
      @controller.send(:authorize_parent_recording_from_params!)
    end

    assert_equal "/", @controller.redirected_to
    assert_equal "Parent recording not found.", @controller.flash_payload[:alert]
  end

  def test_parent_recording_from_params_finds_by_recording_id
    @controller.params_hash = { parent_recording_id: "parent-1" }
    parent_recording = @parent_recording

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      recording_class.define_singleton_method(:find_by!) do |**_kwargs|
        raise "should not fallback when find succeeds"
      end

      assert_equal parent_recording, @controller.send(:parent_recording_from_params)
    end
  end

  def test_parent_recording_from_params_falls_back_to_recordable_id
    @controller.params_hash = { parent_recording_id: "folder-recordable-id" }
    parent_recording = @parent_recording

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) do |_id|
        raise ActiveRecord::RecordNotFound, "missing"
      end
      recording_class.define_singleton_method(:find_by!) do |**kwargs|
        raise "unexpected fallback lookup" unless kwargs == { recordable_id: "folder-recordable-id" }

        parent_recording
      end

      assert_equal parent_recording, @controller.send(:parent_recording_from_params)
    end
  end

  def test_parent_recording_label_falls_back_to_type_and_id
    parent_recording = ParentRecording.new("parent-42", Recordable.new(nil, nil), "Folder")

    assert_equal "Folder parent-42", @controller.send(:parent_recording_label, parent_recording)
  end

  def test_orderable_parent_recordings_supports_where_not_scope
    parent_recording = build_parent_recording_with_groups({
                                                            "pages" => { group_key: "pages", allows: ["Page"] }
                                                          })
    relation = Struct.new(:records) do
      def not(**)
        self
      end

      def to_a
        records
      end
    end.new([parent_recording])

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:where) { relation }
      rows = @controller.send(:orderable_parent_recordings)
      assert_equal [parent_recording], rows
    end
  end

  def test_order_group_definitions_for_returns_empty_when_not_strict
    parent_recording = ParentRecording.new("parent-1", Object.new, "Object")

    assert_equal({}, @controller.send(:order_group_definitions_for, parent_recording, strict: false))
  end

  def test_order_group_definitions_for_raises_when_strict
    parent_recording = ParentRecording.new("parent-1", Object.new, "Object")

    assert_raises(NoMethodError) do
      @controller.send(:order_group_definitions_for, parent_recording)
    end
  end

  def test_authorize_parent_recording_denies_when_hook_returns_false
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { false }

    result = @controller.send(:authorize_parent_recording!, @parent_recording)

    assert_equal({ alert: "You are not allowed to access that recording order." }, result)
    assert_equal "/", @controller.redirected_to
    assert_equal "You are not allowed to access that recording order.", @controller.flash_payload[:alert]
  end

  def test_safe_local_redirect_target_allows_local_paths_and_rejects_external_urls
    assert_equal "/return?tab=orders", @controller.send(:safe_local_redirect_target, "/return?tab=orders")
    assert_nil @controller.send(:safe_local_redirect_target, "https://example.com/orders")
    assert_nil @controller.send(:safe_local_redirect_target, "//example.com/orders")
  end

  def test_append_query_param_adds_query_pairs_to_existing_paths
    assert_equal "/return?selected_order_recording_id=abc123",
                 @controller.send(:append_query_param, "/return", :selected_order_recording_id, "abc123")
    assert_equal "/return?tab=orders&selected_order_recording_id=abc123",
                 @controller.send(:append_query_param, "/return?tab=orders", :selected_order_recording_id, "abc123")
  end

  private

  def build_parent_recording_with_groups(group_definitions, id: "parent-1", recordable_type: "Folder")
    recordable_class = Class.new do
      define_method(:name) { "Folder" }
    end
    recordable_class.define_singleton_method(:recording_studio_order_group_definitions) { group_definitions }

    ParentRecording.new(id, recordable_class.new, recordable_type)
  end

  def with_temporary_recording_class
    had_constant = RecordingStudio.const_defined?(:Recording, false)
    original_constant = RecordingStudio.const_get(:Recording) if had_constant
    temporary_class = Class.new

    RecordingStudio.send(:remove_const, :Recording) if had_constant
    RecordingStudio.const_set(:Recording, temporary_class)
    yield temporary_class
  ensure
    RecordingStudio.send(:remove_const, :Recording) if RecordingStudio.const_defined?(:Recording, false)
    RecordingStudio.const_set(:Recording, original_constant) if had_constant
  end
end
