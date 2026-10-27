# frozen_string_literal: true

require "test_helper"
require "action_controller"

layout_helper = File.join(
  Gem.loaded_specs.fetch("recording_studio").full_gem_path,
  "app/helpers/recording_studio/layout_helper.rb"
)
require layout_helper

ActionController::Base.include(RecordingStudio::ControllerLayout)

require_relative "../app/controllers/recording_studio_orderable/application_controller"
require_relative "../app/controllers/recording_studio_orderable/home_controller"

class ControllerBehaviorTest < Minitest::Test
  def setup
    @orderable_layout = RecordingStudioOrderable.configuration.layout
    @core_layout = RecordingStudio.configuration.layout
    RecordingStudioOrderable.configuration.layout = nil
    RecordingStudio.configuration.layout = nil
  end

  def teardown
    RecordingStudioOrderable.configuration.layout = @orderable_layout
    RecordingStudio.configuration.layout = @core_layout
  end

  def test_nil_layout_falls_through_to_core_then_the_default_template
    RecordingStudio.configuration.layout = "host_pages"

    assert_equal "host_pages", resolved
    assert_equal "host_pages", resolved(RecordingStudioOrderable::HomeController)

    RecordingStudio.configuration.layout = nil

    assert_equal "recording_studio/default_layout", resolved
    assert_equal "recording_studio/default_layout", resolved(RecordingStudioOrderable::HomeController)
  end

  def test_string_layout_name_wins_over_the_core_layout
    RecordingStudioOrderable.configuration.layout = "orderable_pages"
    RecordingStudio.configuration.layout = "host_pages"

    assert_equal "orderable_pages", resolved
  end

  def test_false_layout_renders_no_layout
    RecordingStudioOrderable.configuration.layout = false
    RecordingStudio.configuration.layout = "host_pages"

    assert_equal false, resolved
  end

  def test_keyword_layout_callable_receives_the_controller
    RecordingStudioOrderable.configuration.layout = ->(controller:) { controller.class.name }

    assert_equal "RecordingStudioOrderable::ApplicationController", resolved
    assert_equal "RecordingStudioOrderable::HomeController", resolved(RecordingStudioOrderable::HomeController)
  end

  def test_home_controller_inherits_application_controller
    assert_operator RecordingStudioOrderable::HomeController, :<, RecordingStudioOrderable::ApplicationController
    assert_equal :index, RecordingStudioOrderable::HomeController.action_methods.to_a.first.to_sym
  end

  def test_home_index_is_safe
    controller = RecordingStudioOrderable::HomeController.new

    assert_nil controller.index
  end

  private

  def resolved(controller_class = RecordingStudioOrderable::ApplicationController)
    controller_class.new.recording_studio_resolved_layout
  end
end
