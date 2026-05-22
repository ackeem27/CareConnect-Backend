class CreateActivityLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_logs do |t|
      t.references :user, null: true, foreign_key: true
      t.string :action, null: false
      t.text :details
      t.string :ip_address
      t.string :resource_type
      t.integer :resource_id

      t.timestamps
    end

    add_index :activity_logs, :action
    add_index :activity_logs, :created_at
  end
end
