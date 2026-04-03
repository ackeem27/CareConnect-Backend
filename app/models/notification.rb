class Notification < ApplicationRecord
  belongs_to :user

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }

  TYPES = %w[
    appointment_booked
    appointment_approved
    appointment_rejected
    priority_change
    schedule_update
    walkin_registered
    otp_verification
    system_alert
  ].freeze

  validates :title, presence: true
  validates :notification_type, inclusion: { in: TYPES }, allow_nil: true
end
