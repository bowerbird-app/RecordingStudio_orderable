# frozen_string_literal: true

require "test_helper"

class OrderableLockingTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    Current.actor = @user
    @suffix = SecureRandom.hex(4)
    @workspace = Workspace.create!(name: "Lock Workspace #{@suffix}")
    @workspace_recording = RecordingStudio.root_recording_for(@workspace)
    @folder_recording = @workspace_recording.record(
      Folder, actor: @user, parent_recording: @workspace_recording
    ) do |folder|
      folder.name = "Lock Folder #{@suffix}"
      folder.slug = "lock-folder-#{@suffix}"
    end
    @page_a = record_page("a", 0)
    @page_b = record_page("b", 1)
  end

  teardown do
    Current.actor = nil
    cleanup_lock_tree!
  end

  test "reorder locks the parent before reading siblings" do
    statements = capture_sql do
      @folder_recording.recording_studio_orderable_reorder!(
        ordered_recording_ids: [@page_b.id, @page_a.id],
        actor: @user
      )
    end

    assert_parent_lock_precedes_sibling_read(statements)
    assert_equal [id_string(@page_b), id_string(@page_a)], ordered_child_ids
  end

  test "move and append lock the parent before reading siblings" do
    move_statements = capture_sql do
      @folder_recording.recording_studio_orderable_move!(@page_b, to_index: 0, actor: @user)
    end
    append_statements = capture_sql do
      @folder_recording.recording_studio_orderable_append!(@page_b, actor: @user)
    end

    assert_parent_lock_precedes_sibling_read(move_statements)
    assert_parent_lock_precedes_sibling_read(append_statements)
    assert_equal [id_string(@page_a), id_string(@page_b)], ordered_child_ids
  end

  test "a second reorder waits for the parent lock and reads the committed sibling order" do
    folder_id = @folder_recording.id
    page_a_id = @page_a.id
    page_b_id = @page_b.id
    user_id = @user.id
    ready = Queue.new
    release = Queue.new
    result = Queue.new
    holder_pids = Queue.new
    reorder_pids = Queue.new
    errors = []

    holder = nil
    reorder = nil

    begin
      holder = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          parent = RecordingStudio::Recording.find(folder_id)
          parent.with_lock do
            holder_pids << backend_pid
            ready << true
            release.pop
            RecordingStudio::Recording.find(page_b_id).update!(recording_studio_orderable_position: 0)
            RecordingStudio::Recording.find(page_a_id).update!(recording_studio_orderable_position: 1)
          end
        end
      rescue StandardError => e
        errors << e
        ready << false
      end

      assert ready.pop, "parent lock holder failed: #{error_summary(errors)}"
      holder_pid = holder_pids.pop

      reorder = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          reorder_pids << backend_pid
          parent = RecordingStudio::Recording.find(folder_id)
          parent.recording_studio_orderable_reorder!(
            ordered_recording_ids: [page_a_id, page_b_id],
            actor: User.find(user_id)
          )
          result << parent.events(actions: ["reordered"]).first.metadata
        end
      rescue StandardError => e
        errors << e
        result << e
      end

      wait_until { !reorder_pids.empty? || !reorder.alive? }
      flunk "reorder failed before locking: #{error_summary(errors)}" if errors.any?

      reorder_pid = reorder_pids.pop
      refute_equal holder_pid, reorder_pid
      wait_until { reorder_blocked_on_parent_row?(reorder_pid, holder_pid, folder_id) || !reorder.alive? }
      flunk "reorder failed before locking: #{error_summary(errors)}" if errors.any?

      assert reorder.alive?, "reorder finished before the parent lock was released"
      assert reorder_blocked_on_parent_row?(reorder_pid, holder_pid, folder_id),
             "reorder backend #{reorder_pid} did not wait on holder #{holder_pid} for #{folder_id}\n#{backend_activity(reorder_pid)}"
      assert result.empty?

      release << true
      assert holder.join(5), "parent lock holder did not finish"
      assert reorder.join(5), "reorder did not finish after the parent lock was released"
      flunk error_summary(errors) if errors.any?

      metadata = result.pop
      previous = metadata_list(metadata, :previous_ordered_recording_ids)
      ordered = metadata_list(metadata, :ordered_recording_ids)
      assert_equal [page_b_id.to_s, page_a_id.to_s], previous
      assert_equal [page_a_id.to_s, page_b_id.to_s], ordered
      assert_equal [page_a_id.to_s, page_b_id.to_s], ordered_child_ids
    ensure
      release << true if holder&.alive?
      holder&.join(5)
      reorder&.join(5)
    end
  end

  private

  def cleanup_lock_tree!
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

  def metadata_list(metadata, key)
    value = metadata[key.to_s]
    value = metadata[key.to_sym] if value.nil?
    Array(value).map(&:to_s)
  end

  def record_page(key, position)
    recording = @folder_recording.record(Page, actor: @user, parent_recording: @folder_recording) do |page|
      page.title = "Lock Page #{key} #{@suffix}"
      page.slug = "lock-page-#{key}-#{@suffix}"
      page.body = "Lock test page"
    end
    recording.update!(recording_studio_orderable_position: position)
    recording
  end

  def ordered_child_ids
    @folder_recording.reload.recording_studio_orderable_children.map { |recording| id_string(recording) }
  end

  def id_string(recording)
    recording.id.to_s
  end

  def capture_sql
    statements = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      statements << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    statements
  end

  def assert_parent_lock_precedes_sibling_read(statements)
    lock_at = statements.index { |sql| sql.match?(/FOR UPDATE/i) }
    sibling_at = statements.index { |sql| sibling_order_sql?(sql) }

    assert lock_at, "expected a parent FOR UPDATE lock, got:\n#{statements.join("\n")}"
    assert sibling_at, "expected an ordered sibling read, got:\n#{statements.join("\n")}"
    assert_operator lock_at, :<, sibling_at
  end

  def sibling_order_sql?(sql)
    sql.match?(/recording_studio_orderable_position/i) && sql.match?(/ORDER BY/i)
  end

  def backend_pid
    ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()").to_i
  end

  def reorder_blocked_on_parent_row?(reorder_pid, holder_pid, parent_id)
    ActiveRecord::Base.uncached do
      sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL, reorder_pid, holder_pid, reorder_pid, parent_id])
        SELECT activity.pid
        FROM pg_stat_activity activity
        WHERE activity.pid = ?
          AND activity.state = 'active'
          AND activity.wait_event_type = 'Lock'
          AND EXISTS (
            SELECT 1
            FROM pg_locks holder_transaction
            JOIN pg_locks waiter_transaction
              ON waiter_transaction.transactionid = holder_transaction.transactionid
            WHERE holder_transaction.pid = ?
              AND holder_transaction.locktype = 'transactionid'
              AND holder_transaction.mode = 'ExclusiveLock'
              AND holder_transaction.granted
              AND waiter_transaction.pid = activity.pid
              AND waiter_transaction.locktype = 'transactionid'
              AND NOT waiter_transaction.granted
          )
          AND EXISTS (
            SELECT 1
            FROM pg_locks tuple_lock
            JOIN recording_studio_recordings recording
              ON tuple_lock.locktype = 'tuple'
             AND recording.ctid = format('(%s,%s)', tuple_lock.page, tuple_lock.tuple)::tid
            WHERE tuple_lock.pid = ?
              AND recording.id = ?
          )
      SQL
      ActiveRecord::Base.connection.select_value(sql).to_i == reorder_pid
    end
  end

  def backend_activity(pid)
    ActiveRecord::Base.uncached do
      sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL, pid])
        SELECT pid, state, wait_event_type, wait_event, left(query, 160)
        FROM pg_stat_activity
        WHERE pid = ?
      SQL
      ActiveRecord::Base.connection.select_all(sql).rows.map { |row| row.join(" | ") }.join("\n")
    end
  end

  def wait_until
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.05
    end
  end

  def error_summary(errors)
    errors.map { |error| "#{error.class}: #{error.message}\n#{Array(error.backtrace).first(12).join("\n")}" }
          .join("\n\n")
  end
end
