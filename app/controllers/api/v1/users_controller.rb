module Api
  module V1
    class UsersController < ApplicationController
      before_action :authorize_request, except: [:create, :verify_otp, :resend_otp]

      def index
        @users = User.all
        @users = @users.where(role: params[:role]) if params[:role].present?
        # Filter unapproved doctors for receptionist or other staff listings
        if params[:role] == 'doctor' && @current_user.role != 'admin'
          @users = @users.where(approved: true)
        end
        render json: @users.map { |u| user_payload(u) }, status: :ok
      end

      def update_profile
        @user = @current_user
        profile = profile_params

        # Profile parameters can be sent via multipart form
        @user.name = profile[:name] if profile[:name].present?
        @user.phone = profile[:phone] if profile[:phone].present?

        if profile[:password].present?
          @user.password = profile[:password]
          @user.password_confirmation = profile[:password_confirmation]
        end

        if profile[:avatar].present? && profile[:avatar] != 'null' && profile[:avatar] != 'undefined'
          @user.avatar.attach(profile[:avatar])
        end

        if @user.save
          # Sync patient record if user is a patient
          if @user.patient? && @user.patient
            @user.patient.update(name: @user.name, phone: @user.phone)
          end

          render json: {
            message: 'Profile updated successfully',
            user: user_payload(@user)
          }, status: :ok
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def create
        @user = User.new(user_params)
        if @user.save
          if @user.patient?
            @user.create_patient!(patient_params)
          end

          # Generate and send OTP
          otp = @user.generate_otp!
          begin
            NotificationMailer.send_otp(@user, otp).deliver_now
            # Log OTP explicitly for easy retrieval in development environments
            Rails.logger.info("\n[DEVELOPMENT] OTP Verification Code for #{@user.email}: #{otp}\n")
          rescue => e
            Rails.logger.error("Failed to send OTP email: #{e.message}")
          end

          # Log registration activity
          NotificationService.log_activity(
            user: @user,
            action: 'user_register',
            details: "New #{@user.role} registered: #{@user.email}"
          )

          render json: { 
            message: 'User registered. Please verify your email.',
            token: JsonWebToken.encode(user_id: @user.id),
            user: @user.as_json(except: [:password_digest, :otp_code, :otp_expires_at])
          }, status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/users/verify_otp
      def verify_otp
        # Use case-insensitive search for email and strip whitespace
        email = params[:email].to_s.downcase.strip
        user = User.where("LOWER(email) = ?", email).first
        if user && user.verify_otp!(params[:otp_code])
          render json: { message: 'Email verified successfully', email_verified: true }, status: :ok
        else
          render json: { error: 'Invalid or expired OTP code' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/users/resend_otp
      def resend_otp
        user = User.find_by(email: params[:email])
        if user
          otp = user.generate_otp!
          begin
            NotificationMailer.send_otp(user, otp).deliver_now
            # Log OTP explicitly for easy retrieval in development environments
            Rails.logger.info("\n[DEVELOPMENT] OTP Verification Code for #{user.email}: #{otp}\n")
          rescue => e
            Rails.logger.error("Failed to resend OTP: #{e.message}")
          end
          render json: { message: 'OTP resent to your email' }, status: :ok
        else
          render json: { error: 'User not found' }, status: :not_found
        end
      end

      private

      def user_payload(user)
        user.as_json(except: [:password_digest, :otp_code, :otp_expires_at]).merge(
          avatar_url: user.avatar_url,
          approved: user.approved
        )
      end

      def user_params
        params.permit(:email, :password, :password_confirmation, :role, :name, :phone)
      end

      def profile_params
        if params[:user].present?
          params.require(:user).permit(:name, :phone, :password, :password_confirmation, :avatar)
        else
          params.permit(:name, :phone, :password, :password_confirmation, :avatar)
        end
      end

      def patient_params
        params.permit(:name, :phone, :date_of_birth)
      end
    end
  end
end
