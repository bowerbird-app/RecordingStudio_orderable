# frozen_string_literal: true

require "test_helper"
require "action_controller"
require_relative "../app/controllers/recording_studio_orderable/application_controller"
require_relative "../app/controllers/recording_studio_orderable/recording_order_lists_controller"

class RecordingOrderListsControllerTest < Minitest::Test
  ParentRecording = Struct.new(:id, :recordable, :recordable_type)
  Recordable = Struct.new(:name, :title)

  class ControllerDouble < RecordingStudioOrderable::RecordingOrderListsController
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
    assert_equal "Unable to create that recording order list.", @controller.flash_payload[:alert]
  end

  def test_create_redirects_with_notice_when_list_is_created
    created_at = Time.utc(2024, 1, 2)
    order = Struct.new(:recordings).new([
                                          Struct.new(:id, :created_at).new("order-recording-1", created_at)
                                        ])
    @controller.params_hash = { redirect_to: "/return" }
    @controller.define_singleton_method(:create_named_recording_order) { order }

    @controller.create

    assert_equal "/return?selected_order_recording_id=order-recording-1", @controller.redirected_to
    assert_equal "Created list.", @controller.flash_payload[:notice]
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
    assert_equal "Unable to load that recording order list form.", @controller.flash_payload[:alert]
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
      recording_order_list: { name: "Saved list" }
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
    assert_equal "Saved list", captured[:kwargs][:name]
    assert_same owner, captured[:kwargs][:owner]
    assert_same owner, captured[:kwargs][:actor]
    assert_equal({ source: "recording_studio_orderable.recording_order_lists#create" }, captured[:kwargs][:metadata])
    assert_equal "source-order", captured[:kwargs][:source_order_recording_id]
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
