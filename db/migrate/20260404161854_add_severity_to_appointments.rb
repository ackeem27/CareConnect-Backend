class AddSeverityToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :severity, :string
  end
end
