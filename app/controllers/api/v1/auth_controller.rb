module Api
  module V1
    class AuthController < ApplicationController
      def login
        @user = User.find_by_email(params[:email])
        if @user&.authenticate(params[:password])
          # Check if user is active
          unless @user.active?
            return render json: { error: 'Account has been deactivated. Contact admin.' }, status: :forbidden
          end

          token = JsonWebToken.encode(user_id: @user.id)
          time = Time.now + 24.hours.to_i

          # Update last login
          @user.update_column(:last_login_at, Time.current)

          # Log activity
          NotificationService.log_activity(
            user: @user,
            action: 'user_login',
            details: "#{@user.role.capitalize} logged in: #{@user.email}"
          )

          render json: { 
            token: token, 
            exp: time.strftime("%m-%d-%Y %H:%M"),
            id: @user.id,
            email: @user.email, 
            name: @user.display_name,
            role: @user.role,
            email_verified: @user.email_verified
          }, status: :ok
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      end
    end
  end
end
