# frozen_string_literal: true

class AddUniqueDefaultOrderScopeToRecordingStudioOrders < ActiveRecord::Migration[8.1]
  INDEX_NAME = "idx_rs_recording_orders_unique_default_scope"
  TABLE_NAME = :recording_studio_recording_studio_orders
  BLANK_NAME_PREDICATE = "COALESCE(BTRIM(name), '') = ''"

  def up
    recover_duplicate_unnamed_orders!

    add_index TABLE_NAME,
              %i[parent_recording_id group_key owner_type owner_id],
              unique: true,
              where: BLANK_NAME_PREDICATE,
              name: INDEX_NAME
  end

  def down
    remove_index TABLE_NAME, name: INDEX_NAME
  end

  private

  def recover_duplicate_unnamed_orders!
    duplicate_ids = duplicate_unnamed_order_ids
    return if duplicate_ids.empty?

    say_with_time "Recovering duplicate unnamed recording order scopes" do
      execute(<<~SQL.squish)
        WITH ranked_orders AS (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY parent_recording_id, group_key, owner_type, owner_id
                   ORDER BY created_at DESC NULLS LAST, updated_at DESC NULLS LAST, id DESC
                 ) AS scope_rank
          FROM #{TABLE_NAME}
          WHERE #{BLANK_NAME_PREDICATE}
        )
        UPDATE #{TABLE_NAME} orders
        SET name = CONCAT('Recovered default order ', ranked_orders.scope_rank - 1, ' (', orders.id::text, ')'),
            updated_at = COALESCE(orders.updated_at, CURRENT_TIMESTAMP)
        FROM ranked_orders
        WHERE orders.id = ranked_orders.id
          AND ranked_orders.scope_rank > 1
      SQL
    end
  end

  def duplicate_unnamed_order_ids
    select_values(<<~SQL.squish)
      WITH ranked_orders AS (
        SELECT id,
               ROW_NUMBER() OVER (
                 PARTITION BY parent_recording_id, group_key, owner_type, owner_id
                 ORDER BY created_at DESC NULLS LAST, updated_at DESC NULLS LAST, id DESC
               ) AS scope_rank
        FROM #{TABLE_NAME}
        WHERE #{BLANK_NAME_PREDICATE}
      )
      SELECT id::text
      FROM ranked_orders
      WHERE scope_rank > 1
    SQL
  end
end
