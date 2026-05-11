module Api
  module V1
    class AppointmentsController < ApplicationController
    before_action :authorize_request
    skip_before_action :authorize_request, only: [:queue, :clear_all, :update, :destroy, :walkin]
    skip_before_action :verify_authenticity_token, raise: false

    # POST /api/v1/appointments
    # Triggered by patients who self-book via the web app (smartphone users)
    def create
      patient_id = @current_user.patient&.id

      unless patient_id
        return render json: { error: "No patient profile found for this user" }, status: :unprocessable_entity
      end

      symptoms = params[:symptoms]
      severity = params[:severity] || 'low'

      if symptoms.blank? || !(symptoms.is_a?(Array) || symptoms.is_a?(String))
        return render json: { error: "Please provide symptoms as an array or a description string" }, status: :bad_request
      end

      # Build patient context for Gemini — age + chronic conditions + visit history
      patient      = @current_user.patient
      patient_age  = patient&.date_of_birth ? ((Date.today - patient.date_of_birth.to_date).to_i / 365) : nil
      past_visits  = Appointment.where(patient_id: patient_id).count

      # Extract chronic conditions from past diagnoses (simple keyword approach)
      chronic_conditions = extract_chronic_conditions(patient_id)

      # Run Gemini AI triage with full OPD context
      ai_result = GeminiTriageService.new(
        symptoms:           symptoms,
        severity:           severity,
        patient_age:        patient_age,
        chronic_conditions: chronic_conditions,
        previous_visits:    past_visits
      ).call

      appointment = Appointment.new(
        patient_id:    patient_id,
        symptoms:      ai_result[:detected_symptoms],
        priority_level: ai_result[:priority_level],
        priority_score: ai_result[:priority_score],
        severity:      ai_result[:severity_input],
        ai_reasoning:  ai_result[:reasoning],
        ai_model_used: ai_result[:ai_model_used],
        status:        'pending',
        approval_status: 'pending',
        preferred_date: params[:preferred_date]
      )

      if appointment.save
        NotificationService.notify_appointment_booked(appointment)
        NotificationService.log_activity(
          user: @current_user,
          action: 'appointment_created',
          details: "New appointment. Priority: #{appointment.priority_level} (#{appointment.ai_model_used}), Score: #{appointment.priority_score}",
          resource_type: 'Appointment',
          resource_id: appointment.id
        )

        render json: {
          appointment:      appointment.as_json(include: :patient),
          first_aid_advice: ai_result[:first_aid_advice],
          ai_reasoning:     ai_result[:reasoning],
          ai_model_used:    ai_result[:ai_model_used]
        }, status: :created
      else
        render json: { error: appointment.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    end

      # GET /api/v1/appointments/my
      def my_appointments
        patient = @current_user.patient
        return render json: [] unless patient
        
        appointments = patient.appointments.order(created_at: :desc)
        render json: appointments, status: :ok
      end

      # GET /api/v1/appointments/queue
      def queue
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 20).to_i

        all_appointments = Appointment.where(status: ['pending', 'scheduled', 'arrived', 'in_progress'])
                                      .order(priority_score: :desc, created_at: :asc)
                                      .includes(:patient)

        total = all_appointments.count
        paginated = all_appointments.offset((page - 1) * per_page).limit(per_page)
        
        render json: paginated.map { |appt|
          past_history = Appointment.where(patient_id: appt.patient_id, status: 'completed')
                                    .order(created_at: :desc)
                                    .limit(5)
                                    .select(:id, :diagnosis, :notes, :symptoms, :created_at)

          appt.as_json(include: :patient).merge(past_history: past_history)
        }, status: :ok
      end

      # PATCH/PUT /api/v1/appointments/:id
      def update
        appointment = Appointment.find(params[:id])
        
        update_params = appointment_params
        
        # If diagnosis or notes are being updated, log it
        if update_params[:diagnosis].present? || update_params[:notes].present?
          NotificationService.log_activity(
            user: nil,
            action: 'appointment_completed',
            details: "Diagnosis updated for appointment ##{appointment.id}",
            resource_type: 'Appointment',
            resource_id: appointment.id
          )
        end

        if appointment.update(update_params)
          render json: appointment, status: :ok
        else
          render json: { error: appointment.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/appointments/auto_schedule
      def auto_schedule
        scheduled = AutoSchedulingService.new.call
        
        render json: { 
          message: "Successfully scheduled #{scheduled.count} appointments",
          appointments: scheduled
        }, status: :ok
      end

      # DELETE /api/v1/appointments/:id
      def destroy
        appointment = Appointment.find(params[:id])
        appointment.destroy
        head :no_content
      end

      # POST /api/v1/appointments/walkin
      # FR14: Walk-in patients are auto-integrated into the schedule
      # Used for patients without smartphones — receptionist enters symptoms verbally reported at the desk
      def walkin
        name     = params[:name]
        symptoms = params[:symptoms]
        severity = params[:severity] || 'low'

        if name.blank?
          return render json: { error: "Patient name is required" }, status: :bad_request
        end

        if symptoms.blank?
          return render json: { error: "Symptoms are required" }, status: :bad_request
        end

        # Accept age from receptionist form for Gemini context analysis
        # Fall back to a default DOB if not provided
        patient_age = params[:age].present? ? params[:age].to_i : nil
        dob = if patient_age
                Date.today - patient_age.years
              else
                Date.new(1990, 1, 1)
              end

        # Create guest user + patient record for the walk-in
        email = "walkin_#{name.parameterize.underscore}_#{Time.now.to_i}@careconnect.local"
        user = User.create!(
          email: email,
          password: 'walkin123',
          password_confirmation: 'walkin123',
          role: 'patient',
          name: name,
          email_verified: true
        )
        patient = Patient.create!(
          user: user,
          name: name,
          date_of_birth: dob,
          phone: params[:phone] || 'N/A'
        )

        # Run Gemini AI triage with receptionist-provided context
        ai_result = GeminiTriageService.new(
          symptoms:           symptoms,
          severity:           severity,
          patient_age:        patient_age,
          chronic_conditions: [], # Walk-in: no history available
          previous_visits:    0
        ).call

        appointment = Appointment.create!(
          patient_id:    patient.id,
          symptoms:      ai_result[:detected_symptoms],
          priority_level: ai_result[:priority_level],
          priority_score: ai_result[:priority_score],
          severity:      ai_result[:severity_input],
          ai_reasoning:  ai_result[:reasoning],
          ai_model_used: ai_result[:ai_model_used],
          status:        'pending',
          approval_status: 'pending'
        )

        # FR14: Auto-schedule walk-in into the current day's timeline
        slot = auto_schedule_walkin(appointment)
        if slot
          appointment.update!(
            status: 'scheduled',
            approval_status: 'approved',
            scheduled_at: slot.start_time
          )
        end

        # Log walk-in
        NotificationService.log_activity(
          user: nil,
          action: 'walkin_registered',
          details: "Walk-in patient #{name} auto-scheduled. Priority: #{appointment.priority_level}",
          resource_type: 'Appointment',
          resource_id: appointment.id
        )

        render json: {
          appointment:      appointment.as_json(include: :patient),
          first_aid_advice: ai_result[:first_aid_advice],
          ai_reasoning:     ai_result[:reasoning],
          ai_model_used:    ai_result[:ai_model_used],
          auto_scheduled:   slot.present?,
          scheduled_time:   slot&.start_time
        }, status: :created
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/appointments/:id/finalize
      # FR22: Doctor can save diagnosis and finalize encounter atomically
      def finalize
        appointment = Appointment.find(params[:id])

        diagnosis = params[:diagnosis]
        notes = params[:notes]
        treatment_plan = params[:treatment_plan]
        prescriptions = params[:prescriptions]

        # Build combined notes with structured fields
        combined_notes = []
        combined_notes << "Diagnosis: #{diagnosis}" if diagnosis.present?
        combined_notes << "Treatment Plan: #{treatment_plan}" if treatment_plan.present?
        combined_notes << "Prescriptions: #{prescriptions}" if prescriptions.present?
        combined_notes << "Notes: #{notes}" if notes.present?

        appointment.update!(
          diagnosis: diagnosis.presence || appointment.diagnosis,
          notes: combined_notes.join("\n"),
          status: 'completed'
        )

        NotificationService.log_activity(
          user: nil,
          action: 'encounter_finalized',
          details: "Encounter finalized for appointment ##{appointment.id}. Diagnosis: #{diagnosis}",
          resource_type: 'Appointment',
          resource_id: appointment.id
        )

        render json: appointment.as_json(include: :patient), status: :ok
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # DELETE /api/v1/appointments/clear_all
      def clear_all
        Appointment.where(status: 'pending').destroy_all
        head :no_content
      end

      private

      def appointment_params
        params.require(:appointment).permit(:status, :priority_level, :priority_score, :severity, :symptoms, :diagnosis, :notes, :doctor_id, :preferred_date, :ai_reasoning, :ai_model_used)
      end

      # Extract likely chronic conditions from a patient's diagnosis history
      # Looks for common condition keywords in past appointment diagnoses
      def extract_chronic_conditions(patient_id)
        keywords = %w[hypertension diabetes asthma epilepsy hiv tuberculosis copd
                      cancer renal hepatitis arthritis depression anxiety]
        past_diagnoses = Appointment.where(patient_id: patient_id)
                                    .where.not(diagnosis: [nil, ''])
                                    .pluck(:diagnosis)
                                    .join(' ')
                                    .downcase
        keywords.select { |k| past_diagnoses.include?(k) }
      end

      # FR14: Find next available slot for walk-in auto-scheduling
      def auto_schedule_walkin(appointment)
        duration = case appointment.priority_level
                   when 'HIGH' then 30.minutes
                   when 'MEDIUM' then 20.minutes
                   else 15.minutes
                   end

        working_start = SystemConfig.working_hours_start || "08:00"
        working_end = SystemConfig.working_hours_end || "17:00"
        doctor_id = appointment.doctor_id || 1

        start_hour, start_min = working_start.split(':').map(&:to_i)
        end_hour, end_min = working_end.split(':').map(&:to_i)

        current_slot_start = Time.current.change(hour: start_hour, min: start_min)
        day_end = Time.current.change(hour: end_hour, min: end_min)

        # Start from now if past morning
        if Time.current > current_slot_start
          current_slot_start = Time.at((Time.current.to_f / 300).ceil * 300).in_time_zone(Time.current.time_zone)
        end

        while current_slot_start + duration <= day_end
          # Skip lunch break
          if current_slot_start.hour == 12 || (current_slot_start + duration).hour == 12
            current_slot_start = current_slot_start.change(hour: 13, min: 0)
            next
          end

          conflicting = TimeSlot.where(doctor_id: doctor_id, status: 'booked')
                                .where('start_time < ? AND end_time > ?', current_slot_start + duration, current_slot_start)
                                .exists?

          conflict_appt = Appointment.where(status: 'scheduled', doctor_id: doctor_id)
                                     .where('scheduled_at >= ? AND scheduled_at < ?', current_slot_start, current_slot_start + duration)
                                     .where.not(id: appointment.id)
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
# Extracted validation to private methods
# Binary heap for O(log n) insert
# Walk-in patients inserted by priority
