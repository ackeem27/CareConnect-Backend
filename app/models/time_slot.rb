class TimeSlot < ApplicationRecord
  belongs_to :appointment, optional: true

  scope :available, -> { where(status: 'available') }
  scope :booked, -> { where(status: 'booked') }
  scope :for_doctor, ->(doctor_id) { where(doctor_id: doctor_id) }
  scope :for_date, ->(date) { where(start_time: date.beginning_of_day..date.end_of_day) }

  validates :doctor_id, :start_time, :end_time, presence: true
  validate :no_overlap, on: :create

  def duration_minutes
    ((end_time - start_time) / 60).to_i
  end

  private

  def no_overlap
    overlapping = TimeSlot.where(doctor_id: doctor_id, status: 'booked')
                          .where.not(id: id)
                          .where('start_time < ? AND end_time > ?', end_time, start_time)
    if overlapping.exists?
      errors.add(:base, 'Time slot overlaps with an existing booking')
    end
  end
end
