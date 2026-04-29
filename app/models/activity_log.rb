class ActivityLog < ApplicationRecord
  belongs_to :user, optional: true

  scope :recent, -> { order(created_at: :desc) }

  ACTIONS = %w[
    user_login
    user_register
    user_updated
    user_deactivated
    appointment_created
    appointment_approved
    appointment_rejected
    appointment_rescheduled
    appointment_completed
    priority_override
    walkin_registered
    config_updated
    system_event
  ].freeze

  validates :action, presence: true
end
