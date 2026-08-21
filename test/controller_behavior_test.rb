# frozen_string_literal: true

require "test_helper"
require "action_controller"

unless defined?(RecordingStudio::UsesDefaultLayout)
  module RecordingStudio
    module UsesDefaultLayout
      extend ActiveSupport::Concern

      included do
        layout "recording_studio/default_layout"
      end
    end
  end
end

require_relative "../app/controllers/recording_studio_orderable/application_controller"
require_relative "../app/controllers/recording_studio_orderable/home_controller"

class ControllerBehaviorTest < Minitest::Test
  def test_application_controller_uses_default_layout
    assert_includes RecordingStudioOrderable::ApplicationController.included_modules,
                    RecordingStudio::UsesDefaultLayout
  end

  def test_home_controller_inherits_application_controller
    assert_operator RecordingStudioOrderable::HomeController, :<, RecordingStudioOrderable::ApplicationController
    assert_equal :index, RecordingStudioOrderable::HomeController.action_methods.to_a.first.to_sym
  end

  def test_home_index_is_safe
    controller = RecordingStudioOrderable::HomeController.new

    assert_nil controller.index
  end
end
