module Api
  module V1
    class AdminController < ApplicationController
      before_action :authorize_request
      before_action :require_admin

      # GET /api/v1/admin/stats
      def stats
        render json: {
          total_users: User.count,
          active_users: User.where(active: true).count,
          total_patients: User.where(role: :patient).count,
          total_doctors: User.where(role: :doctor).count,
          total_receptionists: User.where(role: :receptionist).count,
          total_admins: User.where(role: :admin).count,
          todays_appointments: Appointment.today.count,
          pending_appointments: Appointment.pending.count,
          system_alerts: ActivityLog.where('created_at > ?', 24.hours.ago).where(action: 'system_event').count
        }, status: :ok
      end

      # GET /api/v1/admin/users
      def users
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 20).to_i
        per_page = [per_page, 100].min # Cap at 100

        all_users = User.all.order(created_at: :desc)
        total = all_users.count
        paginated = all_users.offset((page - 1) * per_page).limit(per_page)

        render json: {
          users: paginated.map { |u|
            {
              id: u.id,
              name: u.display_name,
              email: u.email,
              role: u.role,
              active: u.active,
              approved: u.approved,
              email_verified: u.email_verified,
              last_login_at: u.last_login_at,
              created_at: u.created_at
            }
          },
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: total,
            total_pages: (total.to_f / per_page).ceil
          }
        }, status: :ok
      end

      # PATCH /api/v1/admin/users/:id
      def update_user
        user = User.find(params[:id])
        if user.update(admin_user_params)
          NotificationService.log_activity(
            user: @current_user,
            action: 'user_updated',
            details: "Updated user #{user.email}: #{admin_user_params.to_h}",
            resource_type: 'User',
            resource_id: user.id
          )
          render json: { id: user.id, name: user.display_name, email: user.email, role: user.role, active: user.active, approved: user.approved }, status: :ok
        else
          render json: { error: user.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/admin/users/:id
      def deactivate_user
        user = User.find(params[:id])
        user.update!(active: false)
        NotificationService.log_activity(
          user: @current_user,
          action: 'user_deactivated',
          details: "Deactivated user #{user.email}",
          resource_type: 'User',
          resource_id: user.id
        )
        render json: { message: "User #{user.email} deactivated" }, status: :ok
      end

      # PATCH /api/v1/admin/users/:id/reactivate
      def reactivate_user
        user = User.find(params[:id])
        user.update!(active: true)
        NotificationService.log_activity(
          user: @current_user,
          action: 'user_reactivated',
          details: "Reactivated user #{user.email}",
          resource_type: 'User',
          resource_id: user.id
        )
        render json: { message: "User #{user.email} reactivated" }, status: :ok
      end

      # GET /api/v1/admin/activity_logs
      def activity_logs
        logs = ActivityLog.recent.includes(:user).limit(100)
        render json: logs.map { |log|
          {
            id: log.id,
            action: log.action,
            details: log.details,
            user_name: log.user&.display_name,
            user_email: log.user&.email,
            created_at: log.created_at,
            resource_type: log.resource_type,
            resource_id: log.resource_id
          }
        }, status: :ok
      end

      # GET /api/v1/admin/configs
      def configs
        configs = SystemConfig.all.order(:key)
        render json: configs, status: :ok
      end

      # GET /api/v1/admin/audit_summary
      def audit_summary
        today    = ActivityLog.where('created_at >= ?', Time.current.beginning_of_day).count
        week     = ActivityLog.where('created_at >= ?', 7.days.ago).count
        logins   = ActivityLog.where(action: 'user_login').where('created_at >= ?', 7.days.ago).count
        failures = ActivityLog.where(action: 'login_failed').where('created_at >= ?', 7.days.ago).count
        deactivations = ActivityLog.where(action: 'user_deactivated').where('created_at >= ?', 30.days.ago).count

        render json: {
          events_today: today,
          events_this_week: week,
          logins_this_week: logins,
          failed_logins_this_week: failures,
          deactivations_this_month: deactivations
        }, status: :ok
      end

      # PATCH /api/v1/admin/configs/:id
      def update_config
        config = SystemConfig.find(params[:id])
        if config.update(value: params[:value], updated_by: @current_user.id)
          NotificationService.log_activity(
            user: @current_user,
            action: 'config_updated',
            details: "Updated config #{config.key} to #{config.value}",
            resource_type: 'SystemConfig',
            resource_id: config.id
          )
          render json: config, status: :ok
        else
          render json: { error: config.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end

      private

      def require_admin
        unless @current_user.admin?
          render json: { error: 'Unauthorized. Admin access required.' }, status: :forbidden
        end
      end

      def admin_user_params
        params.permit(:role, :active, :name, :email, :approved)
      end
    end
  end
end
