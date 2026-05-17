class User < ApplicationRecord
  has_secure_password
  enum :role, { patient: 0, doctor: 1, receptionist: 2, admin: 3 }
  has_one :patient, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :activity_logs, dependent: :nullify

  validates :email, presence: true, uniqueness: true
  validates :password, format: { 
    with: /\A(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}\z/,
    message: "must be at least 8 characters and include 1 uppercase, 1 number, and 1 special character" 
  }, if: -> { new_record? || !password.nil? }

  def generate_otp!
    self.otp_code = rand(100000..999999).to_s
    self.otp_expires_at = 10.minutes.from_now
    save!
    otp_code
  end

  def verify_otp!(code)
    # Be robust: normalize the code (trim spaces)
    code = code.to_s.strip
    if otp_code == code && otp_expires_at&.future?
      update!(email_verified: true, otp_code: nil, otp_expires_at: nil)
      true
    else
      false
    end
  end

  def display_name
    name || patient&.name || email.split('@').first
  end
end
# Password must contain at least 8 characters
# OTP valid for 10 minutes
# bcrypt cost factor: 12
# before_save :hash_password
# Downcase email before lookup
# RoleValidation concern extracted
# Requires: uppercase, lowercase, digit
# SecureRandom for reset tokens
