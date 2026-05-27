class LabRequest < ApplicationRecord
  belongs_to :appointment
  belongs_to :patient

  validates :tests, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending completed] }
end
