class AutoSchedulingService
  def call
    pending_appointments = Appointment.where(status: 'pending')
                                      .order(priority_score: :desc, created_at: :asc)

    return [] if pending_appointments.empty?

    working_start = SystemConfig.working_hours_start || "08:00"
    working_end = SystemConfig.working_hours_end || "17:00"

    start_hour, start_min = working_start.split(':').map(&:to_i)
    end_hour, end_min = working_end.split(':').map(&:to_i)

    current_time = Time.current
    slot_start = current_time.change(hour: start_hour, min: start_min)
    day_end = current_time.change(hour: end_hour, min: end_min)

    # Start from now if we're past morning, rounded to next 5 min
    if current_time > slot_start
      slot_start = Time.at((current_time.to_f / 300).ceil * 300).in_time_zone(current_time.time_zone)
    end

    scheduled_appointments = []

    Appointment.transaction do
      pending_appointments.each do |appointment|
        # Dynamic duration based on priority
        duration = case appointment.priority_level
                   when 'HIGH' then 30.minutes
                   when 'MEDIUM' then 20.minutes
                   else 15.minutes
                   end

        # Find next available slot that doesn't conflict
        while slot_start + duration <= day_end
          # Skip Lunch Break (12:00 PM to 1:00 PM)
          if slot_start.hour == 12 || (slot_start + duration).hour == 12
            slot_start = slot_start.change(hour: 13, min: 0)
            next
          end

          doctor_id = appointment.doctor_id || 1

          conflicting = TimeSlot.where(doctor_id: doctor_id, status: 'booked')
                                .where('start_time < ? AND end_time > ?', slot_start + duration, slot_start)
                                .exists?

          conflict_appt = Appointment.where(status: 'scheduled', doctor_id: doctor_id)
                                     .where('scheduled_at >= ? AND scheduled_at < ?', slot_start, slot_start + duration)
                                     .exists?

          unless conflicting || conflict_appt
            # Create time slot
            TimeSlot.create!(
              doctor_id: doctor_id,
              start_time: slot_start,
              end_time: slot_start + duration,
              appointment: appointment,
              status: 'booked'
            )

            appointment.update!(
              status: 'scheduled',
              scheduled_at: slot_start,
              approval_status: 'approved'
            )

            scheduled_appointments << appointment
            slot_start += duration
            break
          end

          slot_start += 5.minutes # Increment search by 5 mins instead of fixed slots
        end
      end
    end

    scheduled_appointments
  end
end
# Double-booking prevention check
