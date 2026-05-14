class RenameRecordingStudioRecordingOrdersToRecordingStudioRecordingStudioOrders < ActiveRecord::Migration[8.1]
  def change
    rename_table :recording_studio_recording_orders, :recording_studio_recording_studio_orders
  end
end