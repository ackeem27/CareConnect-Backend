class AddOtpToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_code, :string
    add_column :users, :otp_expires_at, :datetime
    add_column :users, :email_verified, :boolean, default: false
    add_column :users, :active, :boolean, default: true
    add_column :users, :name, :string
    add_column :users, :phone, :string
    add_column :users, :last_login_at, :datetime
  end
end
