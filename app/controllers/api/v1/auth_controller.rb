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

      # POST /api/v1/auth/forgot_password
      def forgot_password
        user = User.find_by(email: params[:email]&.downcase&.strip)

        if user&.active?
          # Generate a secure reset token
          raw_token = SecureRandom.urlsafe_base64(32)
          user.update!(
            reset_password_token: Digest::SHA256.hexdigest(raw_token),
            reset_password_sent_at: Time.current
          )
          # Deliver the reset email (mailer handles template)
          begin
            AuthMailer.password_reset(user, raw_token).deliver_now
            # Log the link explicitly for easy retrieval in development environments
            Rails.logger.info("\n[DEVELOPMENT] Password Reset URL: #{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/reset-password?token=#{raw_token}\n")
          rescue => e
            Rails.logger.error("Failed to send password reset email: #{e.message}")
          end
        end

        # Always return success to prevent email enumeration
        render json: { message: 'If that email address is registered, you will receive a reset link shortly.' }, status: :ok
      end

      # POST /api/v1/auth/reset_password
      def reset_password
        hashed = Digest::SHA256.hexdigest(params[:token].to_s)
        user = User.find_by(reset_password_token: hashed)

        if user.nil? || user.reset_password_sent_at < 15.minutes.ago
          return render json: { error: 'Reset link is invalid or has expired.' }, status: :unprocessable_entity
        end

        if params[:password] != params[:password_confirmation]
          return render json: { error: 'Passwords do not match.' }, status: :unprocessable_entity
        end

        if user.update(
          password: params[:password],
          password_confirmation: params[:password_confirmation],
          reset_password_token: nil,
          reset_password_sent_at: nil
        )
          NotificationService.log_activity(
            user: user,
            action: 'password_reset',
            details: "Password was reset for #{user.email}"
          )
          render json: { message: 'Password has been reset successfully. You may now log in.' }, status: :ok
        else
          render json: { error: user.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      end
    end
  end
end
