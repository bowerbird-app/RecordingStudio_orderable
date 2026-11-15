# frozen_string_literal: true

require "test_helper"

class OrderableMoveQueriesTest < ActiveSupport::TestCase
  SIBLING_COUNT = 50

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    Current.actor = @user
    suffix = SecureRandom.hex(4)
    workspace = Workspace.create!(name: "Move queries #{suffix}")
    root = RecordingStudio.create_root_recording!(workspace, actor: @user)
    grant_demo_owner!(recording: root, actor: @user)
    @folder = root.record(Folder, actor: @user, parent_recording: root) do |folder|
      folder.name = "Move queries #{suffix}"
      folder.slug = "move-queries-#{suffix}"
    end
    @pages = Array.new(SIBLING_COUNT) { |index| record_page(suffix, index) }
  end

  teardown do
    Current.actor = nil
  end

  test "one move in a long sibling list issues a bounded number of position updates" do
    moving = @pages.first
    timestamps = @pages.to_h { |page| [page.id, page.reload.updated_at] }

    statements = capture_sql do
      @folder.recording_studio_orderable_move!(moving, to_index: SIBLING_COUNT - 1, actor: @user)
    end

    position_updates = statements.select { |sql| position_update?(sql) }
    assert_equal 2, position_updates.size, position_updates.join("\n")
    assert_equal 1, position_updates.count { |sql| range_shift?(sql) }
    assert_equal 0, position_updates.count { |sql| sql.match?(/updated_at/i) }

    children = @folder.reload.recording_studio_orderable_children.to_a
    assert_equal (0...SIBLING_COUNT).to_a, children.map(&:recording_studio_orderable_position)
    assert_equal @pages.drop(1).map(&:id) + [moving.id], children.map(&:id)
    timestamps.each do |id, updated_at|
      assert_equal updated_at, RecordingStudio::Recording.find(id).updated_at
    end
  end

  private

  def record_page(suffix, index)
    recording = @folder.record(Page, actor: @user, parent_recording: @folder) do |page|
      page.title = "Move query page #{index}"
      page.slug = "move-query-#{suffix}-#{index}"
      page.body = "Move query page"
    end
    recording.update!(recording_studio_orderable_position: index)
    recording
  end

  def capture_sql
    statements = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      statements << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    statements
  end

  def position_update?(sql)
    sql.match?(/\AUPDATE/i) && sql.include?("recording_studio_orderable_position")
  end

  def range_shift?(sql)
    sql.match?(/recording_studio_orderable_position" = "recording_studio_orderable_position" - 1/)
  end
end
