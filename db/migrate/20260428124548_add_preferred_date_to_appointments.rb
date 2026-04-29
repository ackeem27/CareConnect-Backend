class AddPreferredDateToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :preferred_date, :datetime
  end
end
