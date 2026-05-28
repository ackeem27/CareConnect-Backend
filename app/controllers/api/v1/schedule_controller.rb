module Api
  module V1
    class ScheduleController < ApplicationController
      before_action :authorize_request, except: [:index]
      skip_before_action :authorize_request, only: [:index]

      # GET /api/v1/schedule
      def index
        appointments = Appointment.includes(:patient, :doctor, :time_slot)
                                  .where.not(status: 'cancelled')
                                  .order(priority_score: :desc, created_at: :asc)

        render json: appointments.map { |appt|
          slot = appt.time_slot
          slot_doctor = slot&.doctor_id ? User.find_by(id: slot.doctor_id) : nil
          {
            id: appt.id,
            patient: appt.patient.as_json(only: [:id, :name, :phone, :date_of_birth]),
            symptoms: appt.symptoms,
            priority_level: appt.priority_level,
            priority_score: appt.priority_score,
            severity: appt.severity,
            status: appt.status,
            approval_status: appt.approval_status,
            diagnosis: appt.diagnosis,
            notes: appt.notes,
            doctor_id: appt.doctor_id,
            doctor: appt.doctor&.as_json(only: [:id, :name, :email]),
            created_at: appt.created_at,
            scheduled_at: appt.scheduled_at,
            time_slot: slot ? {
              id: slot.id,
              start_time: slot.start_time,
              end_time: slot.end_time,
              doctor_id: slot.doctor_id,
              doctor: slot_doctor&.as_json(only: [:id, :name, :email]),
              status: slot.status
            } : nil
          }
        }, status: :ok
      end

      # POST /api/v1/schedule/approve/:id
      def approve
        appointment = Appointment.find(params[:id])
        
        doctor_id = params[:doctor_id].presence || User.doctor.where(approved: true, active: true).first&.id || User.doctor.where(active: true).first&.id
        unless doctor_id
          return render json: { error: "No available doctor found for assignment." }, status: :unprocessable_entity
        end
        
        if params[:scheduled_at].present?
          new_time = Time.parse(params[:scheduled_at])
          duration = case appointment.priority_level
                     when 'HIGH' then 30.minutes
                     when 'MEDIUM' then 20.minutes
                     else 15.minutes
                     end
                     
          slot = TimeSlot.create!(
            doctor_id: doctor_id,
            start_time: new_time,
            end_time: new_time + duration,
            appointment: appointment,
            status: 'booked'
          )
        else
          # Auto-assign a time slot
          appointment.doctor_id = doctor_id
          slot = find_next_available_slot(appointment)
        end

        appointment.update!(
          doctor_id: doctor_id,
          approval_status: 'approved',
          approved_by: @current_user.id,
          status: 'scheduled',
          scheduled_at: slot&.start_time
        )

        NotificationMailer.appointment_confirmation(appointment.patient.user, appointment).deliver_later rescue nil

        NotificationService.notify_appointment_approved(appointment)
        NotificationService.log_activity(
          user: @current_user,
          action: 'appointment_approved',
          details: "Approved appointment ##{appointment.id} for #{appointment.patient.name}",
          resource_type: 'Appointment',
          resource_id: appointment.id
        )

        render json: appointment.as_json(include: :patient), status: :ok
      end

      # POST /api/v1/schedule/reject/:id
      def reject
        appointment = Appointment.find(params[:id])
        reason = params[:reason]

        appointment.update!(
          approval_status: 'rejected',
          approved_by: @current_user.id,
          status: 'rejected'
        )

        NotificationService.notify_appointment_rejected(appointment, reason)
        NotificationService.log_activity(
          user: @current_user,
          action: 'appointment_rejected',
          details: "Rejected appointment ##{appointment.id}. Reason: #{reason}",
          resource_type: 'Appointment',
          resource_id: appointment.id
        )

        render json: appointment.as_json(include: :patient), status: :ok
      end

      # PATCH /api/v1/schedule/override/:id
      def override
        appointment = Appointment.find(params[:id])

        # Store original values before override
        appointment.original_priority_level ||= appointment.priority_level
        appointment.original_priority_score ||= appointment.priority_score

        old_level = appointment.priority_level
        new_level = params[:priority_level]
        new_score = params[:priority_score]

        appointment.update!(
          priority_level: new_level || appointment.priority_level,
          priority_score: new_score || appointment.priority_score,
          approved_by: @current_user.id
        )

        NotificationService.notify_priority_change(appointment, old_level, new_level) if new_level != old_level
        NotificationService.log_activity(
          user: @current_user,
          action: 'priority_override',
          details: "Override appointment ##{appointment.id}: #{old_level} → #{new_level}",
          resource_type: 'Appointment',
          resource_id: appointment.id
        )

        render json: appointment.as_json(include: :patient), status: :ok
      end

      # PATCH /api/v1/schedule/reschedule/:id
      def reschedule
        appointment = Appointment.find(params[:id])
        new_time = Time.parse(params[:scheduled_at])

        # Remove old time slot
        appointment.time_slot&.update!(status: 'available', appointment_id: nil)

        # Create new time slot
        duration = case appointment.priority_level
                   when 'HIGH' then 30.minutes
                   when 'MEDIUM' then 20.minutes
                   else 15.minutes
                   end

        slot = TimeSlot.create!(
          doctor_id: appointment.doctor_id || 1,
          start_time: new_time,
          end_time: new_time + duration,
          appointment: appointment,
          status: 'booked'
        )

        appointment.update!(scheduled_at: new_time)

        NotificationService.notify_schedule_update(appointment)
        NotificationService.log_activity(
          user: @current_user,
          action: 'appointment_rescheduled',
          details: "Rescheduled appointment ##{appointment.id} to #{new_time}",
          resource_type: 'Appointment',
          resource_id: appointment.id
        )

        render json: appointment.as_json(include: [:patient, :time_slot]), status: :ok
      end

      # PATCH /api/v1/schedule/swap/:id
      def swap
        appointment = Appointment.find(params[:id])
        direction = params[:direction] # 'up' or 'down'
        
        # Find adjacent appointment
        operator = direction == 'up' ? '<' : '>'
        order = direction == 'up' ? 'DESC' : 'ASC'
        
        adjacent_appt = Appointment.where(status: 'scheduled')
                                   .where("scheduled_at #{operator} ?", appointment.scheduled_at)
                                   .order("scheduled_at #{order}")
                                   .first

        if adjacent_appt
          # Swap scheduled_at times
          time1 = appointment.scheduled_at
          time2 = adjacent_appt.scheduled_at
          
          # Also swap time_slots if they exist
          slot1 = appointment.time_slot
          slot2 = adjacent_appt.time_slot
          
          # Use transaction
          Appointment.transaction do
            appointment.update!(scheduled_at: time2)
            adjacent_appt.update!(scheduled_at: time1)
            
            if slot1 && slot2
              st1, et1 = slot1.start_time, slot1.end_time
              st2, et2 = slot2.start_time, slot2.end_time
              slot1.update!(start_time: st2, end_time: et2)
              slot2.update!(start_time: st1, end_time: et1)
            end
          end
          
          NotificationService.log_activity(
            user: @current_user,
            action: 'appointment_swapped',
            details: "Swapped appointments ##{appointment.id} and ##{adjacent_appt.id}",
            resource_type: 'Appointment',
            resource_id: appointment.id
          )
        end
        
        render json: { success: true }, status: :ok
      end

      private

      def find_next_available_slot(appointment)
        duration = case appointment.priority_level
                   when 'HIGH' then 30.minutes
                   when 'MEDIUM' then 20.minutes
                   else 15.minutes
                   end

        working_start = SystemConfig.working_hours_start || "08:00"
        working_end = SystemConfig.working_hours_end || "17:00"
        doctor_id = appointment.doctor_id || User.doctor.where(approved: true, active: true).first&.id || User.doctor.where(active: true).first&.id
        return nil unless doctor_id

        today = Date.current
        start_hour, start_min = working_start.split(':').map(&:to_i)
        end_hour, end_min = working_end.split(':').map(&:to_i)

        current_slot_start = Time.current.change(hour: start_hour, min: start_min)
        day_end = Time.current.change(hour: end_hour, min: end_min)

        # If we're past the start time, begin from the next available slot (rounded to 5m)
        if Time.current > current_slot_start
          current_slot_start = Time.at((Time.current.to_f / 300).ceil * 300).in_time_zone(Time.current.time_zone)
        end

        # Find first non-conflicting slot
        while current_slot_start + duration <= day_end
          # Skip Lunch Break (12:00 PM to 1:00 PM)
          if current_slot_start.hour == 12 || (current_slot_start + duration).hour == 12
            current_slot_start = current_slot_start.change(hour: 13, min: 0)
            next
          end

          conflicting = TimeSlot.where(doctor_id: doctor_id, status: 'booked')
                                .where('start_time < ? AND end_time > ?', current_slot_start + duration, current_slot_start)
                                .exists?

          conflict_appt = Appointment.where(status: 'scheduled', doctor_id: doctor_id)
                                     .where('scheduled_at >= ? AND scheduled_at < ?', current_slot_start, current_slot_start + duration)
                                     .exists?

          unless conflicting || conflict_appt
            slot = TimeSlot.create!(
              doctor_id: doctor_id,
              start_time: current_slot_start,
              end_time: current_slot_start + duration,
              appointment: appointment,
              status: 'booked'
            )
            return slot
          end

          current_slot_start += 5.minutes
        end

        nil # No available slot today
      end
    end
  end
end
