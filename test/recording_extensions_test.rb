# frozen_string_literal: true

require "test_helper"

class RecordingExtensionsTest < Minitest::Test
  def setup
    @recording = Object.new
    @recording.extend(RecordingStudioOrderable::RecordingExtensions)
    @owner = Struct.new(:id).new("owner-1")
  end

  def test_recording_order_recordings_delegates_to_manager
    RecordingStudioOrderable::RecordingOrderManager.stub(
      :recording_order_recordings,
      lambda do |recording, group_key, owner:, named_only:, orderable_name:|
        assert_same @recording, recording
        assert_equal :pages, group_key
        assert_same @owner, owner
        assert_equal false, named_only
        assert_nil orderable_name
        [:recording]
      end
    ) do
      assert_equal [:recording], @recording.recording_order_recordings(:pages, owner: @owner)
    end
  end

  def test_recording_orders_delegates_to_manager
    RecordingStudioOrderable::RecordingOrderManager.stub(:recording_orders, lambda do |recording, owner:, group:,
                                                                                         orderable_name:, named_only:|
      assert_same @recording, recording
      assert_same @owner, owner
      assert_nil group
      assert_nil orderable_name
      assert_equal false, named_only
      [:order]
    end) do
      assert_equal [:order], @recording.recording_orders(owner: @owner)
    end
  end

  def test_recording_orders_delegates_optional_group_and_name_filters
    RecordingStudioOrderable::RecordingOrderManager.stub(:recording_orders, lambda do |recording, owner:, group:,
                                                                                         orderable_name:, named_only:|
      assert_same @recording, recording
      assert_same @owner, owner
      assert_equal "Page", group
      assert_equal "Named list", orderable_name
      assert_equal false, named_only
      [:filtered_order]
    end) do
      assert_equal(
        [:filtered_order],
        @recording.recording_orders(owner: @owner, group: "Page", orderable_name: "Named list")
      )
    end
  end

  def test_recording_order_recording_for_delegates_to_manager
    RecordingStudioOrderable::RecordingOrderManager.stub(
      :recording_order_recording_for,
      lambda do |recording, group_key, owner:|
        assert_same @recording, recording
        assert_equal :pages, group_key
        assert_same @owner, owner
        :recording_order_recording
      end
    ) do
      assert_equal :recording_order_recording, @recording.recording_order_recording_for(:pages, owner: @owner)
    end
  end

  def test_recording_order_for_delegates_to_manager
    RecordingStudioOrderable::RecordingOrderManager.stub(:recording_order_for, lambda do |recording, group_key, owner:|
      assert_same @recording, recording
      assert_equal :pages, group_key
      assert_same @owner, owner
      :recording_order
    end) do
      assert_equal :recording_order, @recording.recording_order_for(:pages, owner: @owner)
    end
  end

  def test_find_or_create_recording_order_delegates_to_manager
    RecordingStudioOrderable::RecordingOrderManager.stub(
      :find_or_create_recording_order!,
      lambda do |recording, group_key, **options|
        assert_same @recording, recording
        assert_equal :pages, group_key
        assert_equal({ owner: @owner }, options)
        :created
      end
    ) do
      assert_equal :created, @recording.find_or_create_recording_order!(:pages, owner: @owner)
    end
  end

  def test_children_for_order_group_delegates_to_manager
    RecordingStudioOrderable::RecordingOrderManager.stub(:eligible_children_for, lambda do |recording, group_key|
      assert_same @recording, recording
      assert_equal :pages, group_key
      [:child]
    end) do
      assert_equal [:child], @recording.children_for_order_group(:pages)
    end
  end

  def test_ordered_children_for_delegates_to_manager
    RecordingStudioOrderable::RecordingOrderManager.stub(
      :ordered_children_for,
      lambda do |recording, group_key, owner:|
        assert_same @recording, recording
        assert_equal :pages, group_key
        assert_same @owner, owner
        [:ordered_child]
      end
    ) do
      assert_equal [:ordered_child], @recording.ordered_children_for(:pages, owner: @owner)
    end
  end
end
