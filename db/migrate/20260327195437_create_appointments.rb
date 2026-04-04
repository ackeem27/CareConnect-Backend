class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments do |t|
      t.references :patient, null: false, foreign_key: true
      t.text :symptoms
      t.string :priority_level
      t.integer :priority_score
      t.string :status
      t.datetime :scheduled_at

      t.timestamps
    end
  end
end
