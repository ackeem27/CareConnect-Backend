class Appointment < ApplicationRecord
  belongs_to :patient
  has_one :time_slot, dependent: :nullify
  serialize :symptoms, coder: JSON

  scope :pending, -> { where(status: 'pending') }
  scope :scheduled, -> { where(status: 'scheduled') }
  scope :today, -> { where(created_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :by_priority, -> { order(priority_score: :desc, created_at: :asc) }

  def priority_color
    case priority_level
    when 'HIGH' then '#ef4444'
    when 'MEDIUM' then '#3b82f6'
    else '#10b981'
    end
  end
end
