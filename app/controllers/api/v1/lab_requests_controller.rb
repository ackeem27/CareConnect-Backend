module Api
  module V1
    class LabRequestsController < ApplicationController
      before_action :authorize_request

      # GET /api/v1/lab_requests/pending
      def pending
        pending_requests = LabRequest.where(status: 'pending').includes(appointment: :patient)
        render json: pending_requests.map { |lr|
          {
            id: lr.id,
            appointment_id: lr.appointment_id,
            patient_name: lr.patient&.name || lr.appointment.patient&.name,
            patient_age: lr.patient&.date_of_birth ? ((Date.today - lr.patient.date_of_birth.to_date).to_i / 365) : nil,
            symptoms: lr.appointment&.symptoms,
            tests: lr.tests,
            status: lr.status,
            requested_at: lr.created_at
          }
        }, status: :ok
      end

      # POST /api/v1/lab_requests/:id/submit_results
      def submit_results
        lr = LabRequest.find(params[:id])
        results = params[:results]
        if results.blank?
          return render json: { error: "Please enter test findings and results." }, status: :bad_request
        end

        lr.update!(status: 'completed', results: results)

        NotificationService.log_activity(
          user: @current_user,
          action: 'lab_results_submitted',
          details: "Submitted lab results for request ##{lr.id}",
          resource_type: 'LabRequest',
          resource_id: lr.id
        )

        render json: { message: "Lab results submitted successfully." }, status: :ok
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
