class SystemConfig < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  def self.get(key, default = nil)
    config = find_by(key: key)
    config ? config.value : default
  end

  def self.set(key, value, description: nil, updated_by: nil)
    config = find_or_initialize_by(key: key)
    config.value = value.to_s
    config.description = description if description
    config.updated_by = updated_by if updated_by
    config.save!
    config
  end

  # Convenience methods
  def self.slot_duration_minutes
    get('slot_duration_minutes', '30').to_i
  end

  def self.working_hours_start
    get('working_hours_start', '08:00')
  end

  def self.working_hours_end
    get('working_hours_end', '17:00')
  end

  def self.max_patients_per_day
    get('max_patients_per_day', '40').to_i
  end
end
