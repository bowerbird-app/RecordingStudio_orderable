# frozen_string_literal: true

require "test_helper"

class ApiRegistrationTest < Minitest::Test
  FakeGrant = Struct.new(:authorized) do
    def authorize!(recording:, role:)
      authorized << [recording, role]
    end
  end

  FakeRecording = Struct.new(:calls) do
    def recording_studio_orderable_reorder!(ordered_recording_ids:, actor:)
      calls << { action: :reorder, ordered_recording_ids: ordered_recording_ids, actor: actor }
      self
    end

    def recording_studio_orderable_move!(recording_id, to_index:, actor:)
      calls << { action: :move_position, recording_id: recording_id, to_index: to_index, actor: actor }
      self
    end
  end

  Context = Struct.new(:recording, :access_grant, :params, :actor, keyword_init: true)

  def test_registration_is_a_noop_without_recording_studio_api
    refute Object.const_defined?(:RecordingStudioApi, false)

    assert_nil RecordingStudio::Orderable::Api.register_capability_action!
  end

  def test_reorder_handler_authorizes_and_calls_the_recording_method
    recording = FakeRecording.new([])
    grant = FakeGrant.new([])
    result = RecordingStudio::Orderable::Api::ReorderRecording.call(
      Context.new(
        recording: recording,
        access_grant: grant,
        params: { ordered_recording_ids: %w[b a] },
        actor: :api_client
      )
    )

    assert_same recording, result
    assert_equal [[recording, :edit]], grant.authorized
    assert_equal(
      [{ action: :reorder, ordered_recording_ids: %w[b a], actor: :api_client }],
      recording.calls
    )
  end

  def test_reorder_handler_maps_not_authorized_through_api_errors
    grant = Struct.new(:unused) do
      def authorize!(*)
        raise RecordingStudioOrderable::NotAuthorized, "denied"
      end
    end.new(nil)

    error = assert_raises(NameError) do
      RecordingStudio::Orderable::Api::ReorderRecording.call(
        Context.new(
          recording: FakeRecording.new([]),
          access_grant: grant,
          params: { ordered_recording_ids: %w[a] },
          actor: :api_client
        )
      )
    end

    assert_match(/RecordingStudioApi/, error.message)
  end

  def test_move_position_handler_maps_invalid_child_through_api_errors
    recording = Struct.new(:calls) do
      def recording_studio_orderable_move!(*)
        raise RecordingStudioOrderable::InvalidChild, "not a child"
      end
    end.new([])
    grant = FakeGrant.new([])

    error = assert_raises(NameError) do
      RecordingStudio::Orderable::Api::MovePositionRecording.call(
        Context.new(
          recording: recording,
          access_grant: grant,
          params: { recording_id: "child-1", to_index: 0 },
          actor: :api_client
        )
      )
    end

    assert_match(/RecordingStudioApi/, error.message)
  end

  def test_move_position_handler_authorizes_and_calls_the_recording_method
    recording = FakeRecording.new([])
    grant = FakeGrant.new([])
    result = RecordingStudio::Orderable::Api::MovePositionRecording.call(
      Context.new(
        recording: recording,
        access_grant: grant,
        params: { recording_id: "child-1", to_index: 0 },
        actor: :api_client
      )
    )

    assert_same recording, result
    assert_equal [[recording, :edit]], grant.authorized
    assert_equal(
      [{ action: :move_position, recording_id: "child-1", to_index: 0, actor: :api_client }],
      recording.calls
    )
  end
end
