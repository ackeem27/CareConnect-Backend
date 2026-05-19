class AddFirstAidAdviceToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :first_aid_advice, :text
  end
end
