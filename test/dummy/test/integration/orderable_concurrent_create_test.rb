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

  test "parallel creates under one orderable parent do not deadlock" do
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
    assert_equal [nil] * CHILD_COUNT, positions
    assert_equal children.map(&:id), children.sort_by { |child| [child.created_at, child.id] }.map(&:id)
  end

  test "a new child keeps a null position and lists after positioned siblings" do
    earlier = record_child(@folder_recording, Page) do |page|
      page.title = "Earlier #{@suffix}"
      page.slug = "earlier-#{@suffix}"
      page.body = "Positioned sibling"
    end
    later = record_child(@folder_recording, Page) do |page|
      page.title = "Later #{@suffix}"
      page.slug = "later-#{@suffix}"
      page.body = "Unpositioned sibling"
    end
    earlier.update!(recording_studio_orderable_position: 0)

    children = @folder_recording.reload.recording_studio_orderable_children.to_a

    assert_nil later.reload.recording_studio_orderable_position
    assert_equal [earlier.id, later.id], children.map(&:id)
  end

  test "positioned children sort before unpositioned children" do
    first = record_child(@folder_recording, Page) do |page|
      page.title = "First #{@suffix}"
      page.slug = "first-#{@suffix}"
      page.body = "First"
    end
    blank_early = record_child(@folder_recording, Page) do |page|
      page.title = "Blank early #{@suffix}"
      page.slug = "blank-early-#{@suffix}"
      page.body = "Blank early"
    end
    second = record_child(@folder_recording, Page) do |page|
      page.title = "Second #{@suffix}"
      page.slug = "second-#{@suffix}"
      page.body = "Second"
    end
    blank_late = record_child(@folder_recording, Page) do |page|
      page.title = "Blank late #{@suffix}"
      page.slug = "blank-late-#{@suffix}"
      page.body = "Blank late"
    end
    first.update!(recording_studio_orderable_position: 0, created_at: Time.utc(2026, 1, 1, 0, 0, 4))
    second.update!(recording_studio_orderable_position: 4, created_at: Time.utc(2026, 1, 1, 0, 0, 1))
    blank_early.update!(created_at: Time.utc(2026, 1, 1, 0, 0, 2))
    blank_late.update!(created_at: Time.utc(2026, 1, 1, 0, 0, 3))

    statements = capture_sql do
      @listed = @folder_recording.reload.recording_studio_orderable_children.to_a
    end

    assert_equal [first.id, second.id, blank_early.id, blank_late.id], @listed.map(&:id)
    assert_includes sibling_order_sql(statements), "NULLS LAST"
  end

  test "move and append give unpositioned siblings contiguous positions" do
    first = record_child(@folder_recording, Page) do |page|
      page.title = "Move first #{@suffix}"
      page.slug = "move-first-#{@suffix}"
      page.body = "Move first"
    end
    second = record_child(@folder_recording, Page) do |page|
      page.title = "Move second #{@suffix}"
      page.slug = "move-second-#{@suffix}"
      page.body = "Move second"
    end
    third = record_child(@folder_recording, Page) do |page|
      page.title = "Move third #{@suffix}"
      page.slug = "move-third-#{@suffix}"
      page.body = "Move third"
    end
    first.update!(recording_studio_orderable_position: 0)

    @folder_recording.recording_studio_orderable_move!(third, to_index: 0, actor: @user)

    moved = [third, first, second].map { |child| child.reload.recording_studio_orderable_position }
    assert_equal [0, 1, 2], moved

    @folder_recording.recording_studio_orderable_append!(third, actor: @user)

    appended = @folder_recording.reload.recording_studio_orderable_children.map(&:recording_studio_orderable_position)
    assert_equal [0, 1, 2], appended
    assert_equal third.id, @folder_recording.recording_studio_orderable_children.last.id
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
    keeper.update!(recording_studio_orderable_position: 0)
    restored.update!(recording_studio_orderable_position: 1)
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

  def sibling_order_sql(statements)
    statements.find do |sql|
      sql.match?(/ORDER BY/i) && sql.include?("recording_studio_orderable_position")
    end.to_s
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
