# frozen_string_literal: true

require "test_helper"

class OrderableChildrenPreloadTest < ActiveSupport::TestCase
  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |user|
      user.password = "Password"
      user.password_confirmation = "Password"
    end
    Current.actor = @user
    @suffix = SecureRandom.hex(4)
    @previous_folder_options = RecordingStudio.capability_options(:orderable, for: "Folder")
    RecordingStudio.set_capability_options(:orderable, on: "Folder", allows: %w[Page Folder])

    workspace = Workspace.create!(name: "Preload Workspace #{@suffix}")
    @workspace_recording = RecordingStudio.root_recording_for(workspace)
    grant_demo_owner!(recording: @workspace_recording, actor: @user)
    @folder = @workspace_recording.record(
      Folder, actor: @user, parent_recording: @workspace_recording
    ) do |folder|
      folder.name = "Preload Folder #{@suffix}"
      folder.slug = "preload-folder-#{@suffix}"
    end
    @pages = Array.new(2) { |index| record_page(index) }
    @nested_folders = Array.new(2) { |index| record_nested_folder(index) }
    (@pages + @nested_folders).each_with_index do |recording, index|
      recording.update!(recording_studio_orderable_position: index)
    end
  end

  teardown do
    Current.actor = nil
    restore_folder_options!
  end

  test "ordered children preload one recordable query per type" do
    relation = @folder.reload.recording_studio_orderable_children

    assert_kind_of ActiveRecord::Relation, relation
    assert relation.exists?
    assert relation.where(id: @pages.first.id).exists?
    assert_equal @pages.first.id, relation.find_by(id: @pages.first.id).id
    assert_equal 3, relation.maximum(:recording_studio_orderable_position)

    children = nil
    statements = capture_sql do
      ActiveRecord::Base.uncached do
        children = @folder.reload.recording_studio_orderable_children.to_a
        children.each(&:recordable)
      end
    end

    assert_equal (@pages + @nested_folders).map(&:id), children.map(&:id)
    children.each do |recording|
      assert recording.association(:recordable).loaded?
      assert_equal recording.recordable_type, recording.recordable.class.name
    end

    page_selects = recordable_selects(statements, "pages")
    folder_selects = recordable_selects(statements, "folders")
    assert_equal 1, page_selects.size, page_selects.join("\n")
    assert_equal 1, folder_selects.size, folder_selects.join("\n")
    assert_match(/ IN /i, page_selects.first)
    assert_match(/ IN /i, folder_selects.first)
  end

  test "reorder queries eligible children after the parent lock" do
    @folder.child_recordings.load
    assert_predicate @folder.child_recordings, :loaded?

    reversed = (@pages + @nested_folders).map { |recording| recording.id.to_s }.reverse
    statements = capture_sql do
      @folder.recording_studio_orderable_reorder!(
        ordered_recording_ids: reversed,
        actor: @user
      )
    end

    lock_at = statements.index { |sql| sql.match?(/FOR UPDATE/i) }
    sibling_at = statements.index { |sql| sibling_order_sql?(sql) }

    assert lock_at, "expected a parent FOR UPDATE lock, got:\n#{statements.join("\n")}"
    assert sibling_at, "expected an ordered sibling read, got:\n#{statements.join("\n")}"
    assert_operator lock_at, :<, sibling_at
    assert_empty recordable_selects(statements, "pages")
    assert_empty recordable_selects(statements, "folders").grep(/ IN /i)
    assert_equal reversed, @folder.reload.recording_studio_orderable_children.map { |recording| recording.id.to_s }
  end

  private

  def record_page(index)
    @workspace_recording.record(Page, actor: @user, parent_recording: @folder) do |page|
      page.title = "Preload Page #{index} #{@suffix}"
      page.slug = "preload-page-#{index}-#{@suffix}"
      page.body = "Preload"
    end
  end

  def record_nested_folder(index)
    @workspace_recording.record(Folder, actor: @user, parent_recording: @folder) do |folder|
      folder.name = "Nested #{index} #{@suffix}"
      folder.slug = "preload-nested-#{index}-#{@suffix}"
    end
  end

  def restore_folder_options!
    options = @previous_folder_options.respond_to?(:to_h) ? @previous_folder_options.to_h.symbolize_keys : {}
    options = { allows: ["Page"] } if options.empty?
    RecordingStudio.set_capability_options(:orderable, on: "Folder", **options)
  end

  def capture_sql
    statements = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      statements << payload[:sql].to_s
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    statements
  end

  def recordable_selects(statements, table)
    statements.select { |sql| sql.match?(/SELECT/i) && sql.match?(/FROM "#{table}"/i) }
  end

  def sibling_order_sql?(sql)
    sql.match?(/SELECT/i) && sql.match?(/recording_studio_orderable_position/i) && sql.match?(/ORDER BY/i)
  end
end
