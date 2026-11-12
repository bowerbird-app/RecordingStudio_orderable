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

  class FakeApi
    Serializer = Class.new

    module Serializers
      ResourceRecordingSerializer = ApiRegistrationTest::FakeApi::Serializer
    end

    class << self
      attr_accessor :registrations, :existing, :api_names

      def reset!(existing: {}, api_names: %w[public operations])
        self.registrations = []
        self.existing = existing
        self.api_names = api_names
      end

      def capability_action(name, api: :public)
        existing[[name.to_sym, api.to_s]]
      end

      def register_capability_action(name, api: :public, **options)
        registrations << options.merge(name: name, api: api.to_s)
      end

      def configuration
        definitions = api_names.map { |name| Struct.new(:name).new(name) }
        Struct.new(:definitions) do
          def each_api(&)
            definitions.each(&)
          end
        end.new(definitions)
      end
    end
  end

  def setup
    FakeApi.reset!
  end

  def test_registration_is_a_noop_without_recording_studio_api
    refute Object.const_defined?(:RecordingStudioApi, false)

    assert_nil RecordingStudio::Orderable::Api.register_capability_action!
  end

  def test_registration_registers_reorder_and_move_position_on_each_surface
    RecordingStudio::Orderable::Api::Registration.stub(:api_engine, FakeApi) do
      RecordingStudio::Orderable::Api.register_capability_action!
    end

    names = FakeApi.registrations.map { |registration| [registration.fetch(:name), registration.fetch(:api)] }
    assert_equal(
      [[:reorder, "public"], [:move_position, "public"], [:reorder, "operations"], [:move_position, "operations"]],
      names
    )

    reorder = FakeApi.registrations.fetch(0)
    assert_equal :orderable, reorder.fetch(:capability)
    assert_equal :edit, reorder.fetch(:required_role)
    assert_equal :post, reorder.fetch(:http_verb)
    assert_equal RecordingStudio::Orderable::Api::ReorderRecording, reorder.fetch(:handler)
    assert_equal false, reorder.fetch(:input_contract).fetch(:reject_unknown)
    assert_equal "Recording - Reorder", reorder.fetch(:openapi).fetch(:summary)
    assert_equal FakeApi::Serializers::ResourceRecordingSerializer, reorder.fetch(:serializer)

    move_position = FakeApi.registrations.fetch(1)
    assert_equal :orderable, move_position.fetch(:capability)
    assert_equal RecordingStudio::Orderable::Api::MovePositionRecording, move_position.fetch(:handler)
    assert_equal "Recording - Move position", move_position.fetch(:openapi).fetch(:summary)
    refute_equal :move, move_position.fetch(:name)
  end

  def test_registration_does_not_replace_existing_actions
    FakeApi.reset!(existing: { [:reorder, "public"] => Object.new, [:move_position, "public"] => Object.new })

    RecordingStudio::Orderable::Api::Registration.stub(:api_engine, FakeApi) do
      RecordingStudio::Orderable::Api.register_capability_action!
    end

    registered_apis = FakeApi.registrations.map { |registration| registration.fetch(:api) }.uniq
    assert_equal ["operations"], registered_apis
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
