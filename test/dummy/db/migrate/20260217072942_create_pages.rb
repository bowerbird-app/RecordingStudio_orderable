class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages, id: :uuid do |t|
      t.string :title, null: false

      t.timestamps
    end
  end
end
