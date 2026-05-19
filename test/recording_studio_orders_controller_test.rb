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
    attr_accessor :params_hash, :redirected_to, :flash_payload

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

  def test_authenticate_request_calls_configured_hook
    authenticated = false
    RecordingStudioOrderable.configuration.authenticate_controller = lambda do |controller|
      authenticated = controller.equal?(@controller)
    end

    @controller.send(:authenticate_recording_studio_orderable_request!)

    assert_equal true, authenticated
  end

  def test_current_owner_resolver_and_owner_guard_use_configured_owner
    RecordingStudioOrderable.configuration.current_owner_resolver = ->(_controller) { :owner }

    assert_equal :owner, @controller.send(:current_recording_studio_orderable_owner)

    @controller.send(:ensure_current_recording_studio_orderable_owner!)

    assert_nil @controller.redirected_to
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

  def test_create_redirects_when_parent_recording_is_missing
    @controller.params_hash = {}
    @controller.define_singleton_method(:create_named_recording_order) do
      raise ActiveRecord::RecordNotFound, "missing"
    end

    @controller.create

    assert_equal "/", @controller.redirected_to
    assert_equal "Parent recording not found.", @controller.flash_payload[:alert]
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
    assert_equal({ source: "recording_studio_orderable.recording_studio_orders#create" }, captured[:kwargs][:metadata])
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
        :named_recording_order_recordings,
        lambda do |_recording, group_key, owner:|
          assert_nil owner
          group_key == "pages" ? [Struct.new(:id, :recordable).new("order-1", Struct.new(:name).new("Alpha"))] : []
        end
      ) do
        @controller.send(:load_index_context)
      end
    end

    rows = @controller.instance_variable_get(:@type_rows)

    assert_nil @controller.redirected_to
    assert_equal ["Asset", "Page"], rows.map(&:recordable_type)
    assert_equal [0, 1], rows.map(&:custom_orders_count)
  end

  def test_load_index_context_without_parent_recording_id_builds_global_type_rows
    parent_recording_one = build_parent_recording_with_groups({
      "pages" => { group_key: "pages", allows: ["Page"] },
    },
      id: "parent-1",
      recordable_type: "Folder"
    )
    parent_recording_two = build_parent_recording_with_groups({
      "pages" => { group_key: "pages", allows: ["Page"] },
    },
      id: "parent-2",
      recordable_type: "Folder"
    )
    non_orderable_recording = ParentRecording.new(
      "ignored-order",
      Recordable.new("Order", nil),
      "RecordingStudio::RecordingStudioOrder"
    )

    @controller.params_hash = {}

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:all) { [parent_recording_one, parent_recording_two, non_orderable_recording] }
      RecordingStudioOrderable::RecordingOrderManager.stub(
        :named_recording_order_recordings,
        lambda do |recording, _group_key, owner:|
          assert_nil owner
          recording.id == "parent-1" ? [Struct.new(:id, :recordable).new("order-1", Struct.new(:name).new("Alpha"))] : []
        end
      ) do
        @controller.send(:load_index_context)
      end
    end

    rows = @controller.instance_variable_get(:@type_rows)

    assert_nil @controller.redirected_to
    assert_equal 1, rows.size
    assert_equal "Folder", rows.first.recordable_type
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
      RecordingStudioOrderable::RecordingOrderManager.stub(:named_recording_order_recordings, [named_order_recording]) do
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

  def test_redirect_edit_placeholder_redirects_to_show_with_notice
    RecordingStudioOrderable.configuration.authorize_parent_recording = ->(_controller, _parent_recording) { true }
    @controller.params_hash = { parent_recording_id: "parent-1", recordable_type: "Page" }
    @controller.define_singleton_method(:recording_studio_order_path) do |recordable_type, parent_recording_id:|
      "/recording_studio_orders/#{recordable_type}?parent_recording_id=#{parent_recording_id}"
    end
    parent_recording = build_parent_recording_with_groups({
      "pages" => { group_key: "pages", allows: ["Page"] }
    })

    with_temporary_recording_class do |recording_class|
      recording_class.define_singleton_method(:find) { |_id| parent_recording }
      @controller.send(:redirect_edit_placeholder)
    end

    assert_equal "/recording_studio_orders/Page?parent_recording_id=parent-1", @controller.redirected_to
    assert_equal "Editing recording studio orders is not implemented yet.", @controller.flash_payload[:alert]
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
