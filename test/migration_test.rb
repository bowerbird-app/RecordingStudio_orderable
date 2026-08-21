# frozen_string_literal: true

require "test_helper"
require "active_record"
require_relative "../db/migrate/20250101000001_add_recording_studio_orderable_position_to_recording_studio_recordings"

class MigrationTest < Minitest::Test
  def test_position_migration_adds_column_and_index
    migration = AddRecordingStudioOrderablePositionToRecordingStudioRecordings.new
    calls = []

    migration.define_singleton_method(:add_column) { |*args| calls << [:add_column, args] }
    migration.define_singleton_method(:add_index) { |*args, **kwargs| calls << [:add_index, args, kwargs] }

    migration.change

    assert_equal(
      [:add_column, %i[recording_studio_recordings recording_studio_orderable_position integer]],
      calls[0]
    )
    assert_equal(
      [
        :add_index,
        [:recording_studio_recordings, %i[parent_recording_id recording_studio_orderable_position]],
        { name: "idx_rs_recordings_orderable_sibling_position" }
      ],
      calls[1]
    )
  end
end
