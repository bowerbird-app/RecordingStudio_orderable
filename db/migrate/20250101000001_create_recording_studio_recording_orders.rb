# frozen_string_literal: true

class CreateRecordingStudioRecordingOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_recording_orders, id: :uuid do |t|
      t.uuid :parent_recording_id, null: false
      t.string :group_key, null: false
      t.string :name
      t.string :owner_type
      t.uuid :owner_id
      t.uuid :ordered_recording_ids, array: true, default: [], null: false

      t.timestamps
    end

    add_index :recording_studio_recording_orders, :parent_recording_id
    add_index :recording_studio_recording_orders, %i[parent_recording_id group_key]
    add_index :recording_studio_recording_orders, %i[parent_recording_id group_key owner_type owner_id],
              name: "idx_rs_recording_orders_scope_lookup"
  end
end
