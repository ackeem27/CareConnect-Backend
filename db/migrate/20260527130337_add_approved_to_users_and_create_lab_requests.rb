class AddApprovedToUsersAndCreateLabRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :approved, :boolean, default: false

    create_table :lab_requests do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.text :tests, null: false
      t.string :status, default: "pending", null: false
      t.text :results

      t.timestamps
    end

    # Auto-approve existing seeded/created users during migration so they aren't locked out in dev
    reversible do |dir|
      dir.up do
        User.update_all(approved: true)
      end
    end
  end
end
