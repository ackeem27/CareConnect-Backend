class AuthMailer < ApplicationMailer
  # POST /api/v1/auth/forgot_password
  # Sends a secure password-reset link to the user's email address.
  def password_reset(user, raw_token)
    @user      = user
    @raw_token = raw_token
    @reset_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/reset-password?token=#{raw_token}"
    mail(
      to:      @user.email,
      subject: 'CareConnect — Reset Your Password'
    )
  end
end
