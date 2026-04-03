class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :message
      t.string :notification_type
      t.boolean :read, default: false
      t.integer :reference_id
      t.string :reference_type

      t.timestamps
    end

    add_index :notifications, [:user_id, :read]
    add_index :notifications, :notification_type
  end
end
