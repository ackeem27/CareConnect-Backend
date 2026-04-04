module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :authorize_request

      # GET /api/v1/notifications
      def index
        notifications = @current_user.notifications.recent.limit(50)
        unread_count = @current_user.notifications.unread.count

        render json: {
          notifications: notifications,
          unread_count: unread_count
        }, status: :ok
      end

      # PATCH /api/v1/notifications/:id/read
      def mark_read
        notification = @current_user.notifications.find(params[:id])
        notification.update!(read: true)
        render json: notification, status: :ok
      end

      # POST /api/v1/notifications/mark_all_read
      def mark_all_read
        @current_user.notifications.unread.update_all(read: true)
        render json: { message: 'All notifications marked as read' }, status: :ok
      end

      # DELETE /api/v1/notifications/clear
      def clear
        @current_user.notifications.destroy_all
        head :no_content
      end
    end
  end
end
