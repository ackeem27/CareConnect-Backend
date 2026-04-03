class AddUserToPatients < ActiveRecord::Migration[8.1]
  def change
    add_reference :patients, :user, null: false, foreign_key: true
  end
end
