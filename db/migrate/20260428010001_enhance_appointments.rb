class EnhanceAppointments < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :diagnosis, :text
    add_column :appointments, :notes, :text
    add_column :appointments, :doctor_id, :integer
    add_column :appointments, :approval_status, :string, default: 'pending'
    add_column :appointments, :approved_by, :integer
    add_column :appointments, :original_priority_level, :string
    add_column :appointments, :original_priority_score, :integer

    add_index :appointments, :doctor_id
    add_index :appointments, :approval_status
  end
end
