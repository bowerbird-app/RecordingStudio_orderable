class CreateRecordingStudioRecordingOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_recording_orders, id: :uuid do |t|
      t.uuid :parent_recording_id, null: false
      t.string :order_group, null: false
      t.uuid :ordered_recording_ids, array: true, default: [], null: false

      t.timestamps
    end

    add_index :recording_studio_recording_orders, :parent_recording_id
    add_index :recording_studio_recording_orders, %i[parent_recording_id order_group],
              name: "index_rs_recording_orders_on_parent_and_group"
  end
end
