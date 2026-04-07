class CreateTimeSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :time_slots do |t|
      t.integer :doctor_id, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.references :appointment, foreign_key: true
      t.string :status, default: 'available'

      t.timestamps
    end

    add_index :time_slots, :doctor_id
    add_index :time_slots, [:doctor_id, :start_time, :end_time], name: 'index_time_slots_on_doctor_and_time'
    add_index :time_slots, :status
  end
end
