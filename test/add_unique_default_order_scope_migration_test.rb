# frozen_string_literal: true

require "test_helper"
require_relative "../db/migrate/20260515000003_add_unique_default_order_scope_to_recording_studio_orders"

class AddUniqueDefaultOrderScopeMigrationTest < Minitest::Test
  def setup
    @migration = AddUniqueDefaultOrderScopeToRecordingStudioOrders.new
  end

  def test_up_recovers_duplicate_unnamed_orders_before_adding_index
    executed_sql = []
    index_calls = []

    @migration.define_singleton_method(:duplicate_unnamed_order_ids) { %w[order-1 order-2] }
    @migration.define_singleton_method(:say_with_time) { |_message, &block| block.call }
    @migration.define_singleton_method(:execute) { |sql| executed_sql << sql }
    @migration.define_singleton_method(:add_index) { |*args, **kwargs| index_calls << [args, kwargs] }

    @migration.up

    assert_equal 1, executed_sql.size
    assert_includes executed_sql.first, "Recovered default order"
    assert_equal 1, index_calls.size
    assert_equal [:recording_studio_recording_studio_orders, %i[parent_recording_id group_key owner_type owner_id]],
                 index_calls.first[0]
    assert_equal true, index_calls.first[1][:unique]
    assert_equal "idx_rs_recording_orders_unique_default_scope", index_calls.first[1][:name]
  end

  def test_up_adds_index_without_recovery_when_no_duplicates_exist
    executed_sql = []
    index_calls = []

    @migration.define_singleton_method(:duplicate_unnamed_order_ids) { [] }
    @migration.define_singleton_method(:say_with_time) { |_message, &block| block.call }
    @migration.define_singleton_method(:execute) { |sql| executed_sql << sql }
    @migration.define_singleton_method(:add_index) { |*args, **kwargs| index_calls << [args, kwargs] }

    @migration.up

    assert_equal [], executed_sql
    assert_equal 1, index_calls.size
  end
end
