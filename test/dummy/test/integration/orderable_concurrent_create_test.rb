# frozen_string_literal: true

require "test_helper"

class OrderableConcurrentCreateTest < ActiveSupport::TestCase
  CHILD_COUNT = 20

  self.use_transactional_tests = false

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    Current.actor = @user
    @suffix = SecureRandom.hex(4)
    @workspace = Workspace.create!(name: "Create Workspace #{@suffix}")
    @workspace_recording = RecordingStudio.create_root_recording!(@workspace, actor: @user)
    grant_demo_owner!(recording: @workspace_recording, actor: @user)
    @folder_recording = record_child(@workspace_recording, Folder) do |folder|
      folder.name = "Create Folder #{@suffix}"
      folder.slug = "create-folder-#{@suffix}"
    end
  end

  teardown do
    Current.actor = nil
    cleanup_create_tree!
  end

  test "parallel creates under one orderable parent get unique contiguous positions" do
    folder_id = @folder_recording.id
    user_id = @user.id
    suffix = @suffix
    errors = Queue.new
    created_ids = Queue.new
    release = start_together(CHILD_COUNT)

    with_room_for_threads(CHILD_COUNT + 5) do
      threads = Array.new(CHILD_COUNT) do |index|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Current.actor = User.find(user_id)
            parent = RecordingStudio::Recording.find(folder_id)
            release.call
            created = record_child(parent, Page) do |page|
              page.title = "Parallel #{index} #{suffix}"
              page.slug = "parallel-#{index}-#{suffix}"
              page.body = "Parallel create"
            end
            created_ids << created.id
          end
        rescue StandardError => error
          errors << error
        end
      end

      threads.each { |thread| assert thread.join(30), "create thread did not finish" }
    end

    flunk(error_summary(errors)) unless errors.empty?

    children = @folder_recording.reload.recording_studio_orderable_children.to_a
    positions = children.map(&:recording_studio_orderable_position)

    assert_equal CHILD_COUNT, drain(created_ids).uniq.length
    assert_equal (0...CHILD_COUNT).to_a, positions
  end

  test "create locks the parent before inserting the child position" do
    created = nil
    statements = capture_sql do
      created = record_child(@folder_recording, Page) do |page|
        page.title = "Solo #{@suffix}"
        page.slug = "solo-#{@suffix}"
        page.body = "Solo create"
      end
    end

    assert_equal 0, created.recording_studio_orderable_position
    assert_equal 0, created.reload.recording_studio_orderable_position
    assert_parent_lock_precedes_insert(statements)
  end

  test "create on a non-orderable parent leaves position blank" do
    project = record_child(@workspace_recording, Project) do |record|
      record.name = "Create Project #{@suffix}"
      record.slug = "create-project-#{@suffix}"
    end
    created = record_child(project, Page) do |page|
      page.title = "Project Page #{@suffix}"
      page.slug = "project-page-#{@suffix}"
      page.body = "Under a project"
    end

    assert_nil created.reload.recording_studio_orderable_position
  end

  test "create of a child type outside allows leaves position blank" do
    nested = record_child(@folder_recording, Folder) do |folder|
      folder.name = "Nested Folder #{@suffix}"
      folder.slug = "nested-folder-#{@suffix}"
    end

    assert_nil nested.reload.recording_studio_orderable_position
  end

  test "parent change appends on an orderable parent and clears on a project" do
    project = record_child(@workspace_recording, Project) do |record|
      record.name = "Move Project #{@suffix}"
      record.slug = "move-project-#{@suffix}"
    end
    moving = record_child(project, Page) do |page|
      page.title = "Moving Page #{@suffix}"
      page.slug = "moving-page-#{@suffix}"
      page.body = "Changes parent"
    end

    assert_nil moving.reload.recording_studio_orderable_position

    moving.update!(parent_recording: @folder_recording)

    assert_equal 0, moving.reload.recording_studio_orderable_position
    assert_equal moving.id, @folder_recording.reload.recording_studio_orderable_children.last.id

    moving.update!(parent_recording: project)

    assert_nil moving.reload.recording_studio_orderable_position
  end

  test "restoring a trashed child keeps a free position and moves a collision to the end" do
    keeper = record_child(@folder_recording, Page) do |page|
      page.title = "Keeper #{@suffix}"
      page.slug = "keeper-#{@suffix}"
      page.body = "Kept sibling"
    end
    restored = record_child(@folder_recording, Page) do |page|
      page.title = "Restored #{@suffix}"
      page.slug = "restored-#{@suffix}"
      page.body = "Restored sibling"
    end
    kept_position = restored.recording_studio_orderable_position
    restored.update!(trashed_at: Time.current)

    restored.update!(trashed_at: nil)

    assert_equal kept_position, restored.reload.recording_studio_orderable_position

    restored.update!(trashed_at: Time.current)
    restored.update!(
      recording_studio_orderable_position: keeper.reload.recording_studio_orderable_position,
      trashed_at: nil
    )

    assert_equal keeper.reload.recording_studio_orderable_position + 1, restored.reload.recording_studio_orderable_position
  end

  private

  def record_child(parent, type)
    parent.record(type, actor: Current.actor, parent_recording: parent) do |recordable|
      yield recordable
    end
  end

  def with_room_for_threads(size)
    previous = ActiveRecord::Base.connection_db_config
    ActiveRecord::Base.establish_connection(previous.configuration_hash.merge(max_connections: size))
    yield
  ensure
    ActiveRecord::Base.establish_connection(previous) if previous
  end

  def start_together(count)
    mutex = Mutex.new
    waiting = ConditionVariable.new
    arrived = 0
    lambda do
      mutex.synchronize do
        arrived += 1
        if arrived == count
          waiting.broadcast
        else
          waiting.wait(mutex, 15)
        end
      end
    end
  end

  def drain(queue)
    values = []
    values << queue.pop until queue.empty?
    values
  end

  def capture_sql
    statements = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      statements << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    statements
  end

  def assert_parent_lock_precedes_insert(statements)
    update_at = statements.index { |sql| sql.match?(/FOR UPDATE/i) }
    share_at = statements.index { |sql| sql.match?(/FOR SHARE/i) }
    insert_at = statements.index { |sql| sql.match?(/INSERT INTO "recording_studio_recordings"/i) }
    position_updates = statements.select do |sql|
      sql.match?(/UPDATE "recording_studio_recordings"/i) && sql.include?("recording_studio_orderable_position")
    end

    assert update_at, "expected a parent FOR UPDATE lock, got:\n#{statements.join("\n")}"
    assert share_at, "expected the core parent FOR SHARE lock, got:\n#{statements.join("\n")}"
    assert insert_at, "expected a recording insert, got:\n#{statements.join("\n")}"
    assert_operator update_at, :<, share_at, "parent FOR UPDATE ran after FOR SHARE:\n#{statements.join("\n")}"
    assert_operator share_at, :<, insert_at, "parent share lock ran after the child insert:\n#{statements.join("\n")}"
    assert_includes statements[insert_at], "recording_studio_orderable_position"
    assert_empty position_updates
  end

  def cleanup_create_tree!
    return if @workspace_recording.nil?

    root_id = @workspace_recording.id
    recordings = RecordingStudio::Recording.where(root_recording_id: root_id).or(
      RecordingStudio::Recording.where(id: root_id)
    )
    recording_ids = recordings.pluck(:id)
    recordables = recordings.pluck(:recordable_type, :recordable_id)
    RecordingStudio::Event.where(recording_id: recording_ids).delete_all
    RecordingStudio::Recording.where(id: recording_ids).where.not(parent_recording_id: nil).delete_all
    RecordingStudio::Recording.where(id: root_id).delete_all
    recordables.group_by(&:first).each do |type, pairs|
      next unless %w[Page Folder Project Workspace].include?(type)

      type.constantize.where(id: pairs.map(&:last)).delete_all
    end
  end

  def error_summary(errors)
    collected = []
    collected << errors.pop until errors.empty?
    collected.map { |error| "#{error.class}: #{error.message}" }.join("\n")
  end
end
