# frozen_string_literal: true

require "test_helper"

class ApiSourceTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_register_has_one_api_availability_check
    api = File.read(File.join(ROOT, "lib/recording_studio/orderable/api.rb"))
    registration = File.read(File.join(ROOT, "lib/recording_studio/orderable/api/registration.rb"))

    assert_includes api, "Registration.register!"
    assert_equal 1, registration.scan("defined?(RecordingStudioApi)").size
    refute_includes api, "const_set"
    refute_includes api, "remove_const"
    refute_includes registration, "const_set"
    refute_includes registration, "remove_const"
    refute_includes api, "recording_studio_mcp"
    refute_includes registration, "register_tool"
  end

  def test_api_handlers_call_existing_orderable_methods
    reorder = File.read(File.join(ROOT, "lib/recording_studio/orderable/api/reorder_recording.rb"))
    move_position = File.read(File.join(ROOT, "lib/recording_studio/orderable/api/move_position_recording.rb"))

    assert_includes reorder, "recording_studio_orderable_reorder!"
    assert_includes reorder, "access_grant.authorize!"
    assert_includes move_position, "recording_studio_orderable_move!"
    assert_includes move_position, "access_grant.authorize!"
    refute_includes reorder, ":move"
    refute_match(/register_capability_action\(\s*:move[,\s]/, move_position)
  end

  def test_engine_registers_the_api_after_reload
    names = RecordingStudioOrderable::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_orderable.api"
  end

  def test_api_lib_does_not_fake_constants
    Dir[File.join(ROOT, "lib/recording_studio/orderable/api/**/*.rb")].each do |path|
      source = File.read(path)

      refute_includes source, "const_set", path
      refute_includes source, "remove_const", path
    end
  end
end
