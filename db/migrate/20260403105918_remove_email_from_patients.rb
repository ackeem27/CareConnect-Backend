class RemoveEmailFromPatients < ActiveRecord::Migration[8.1]
  def change
    remove_column :patients, :email, :string
  end
end
