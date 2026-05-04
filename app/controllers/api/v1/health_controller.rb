module Api
  module V1
    class HealthController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false

      # GET /api/v1/health
      def show
        db_status = begin
          ActiveRecord::Base.connection.execute("SELECT 1")
          "connected"
        rescue => e
          "error: #{e.message}"
        end

        render json: {
          status: "ok",
          timestamp: Time.current.iso8601,
          database: db_status,
          version: "1.0.0",
          uptime_seconds: (Time.current - Rails.application.config.boot_time).to_i,
          counts: {
            users: User.count,
            patients: Patient.count,
            appointments_today: Appointment.today.count,
            pending_appointments: Appointment.pending.count
          }
        }, status: :ok
      rescue => e
        render json: { status: "error", message: e.message }, status: :internal_server_error
      end
    end
  end
end
