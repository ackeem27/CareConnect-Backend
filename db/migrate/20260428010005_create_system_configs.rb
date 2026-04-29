class CreateSystemConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :system_configs do |t|
      t.string :key, null: false
      t.string :value, null: false
      t.string :description
      t.integer :updated_by

      t.timestamps
    end

    add_index :system_configs, :key, unique: true
  end
end
