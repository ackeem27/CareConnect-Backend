class NotificationMailer < ApplicationMailer
  default from: 'noreply@careconnect.com'

  def send_otp(user, otp_code)
    @user = user
    @otp_code = otp_code
    mail(to: @user.email, subject: 'CareConnect — Your Verification Code')
  end

  def send_notification(user, title, message)
    @user = user
    @title = title
    @message = message
    mail(to: @user.email, subject: "CareConnect — #{title}")
  end

  def appointment_confirmation(user, appointment)
    @user = user
    @appointment = appointment
    mail(to: @user.email, subject: 'CareConnect — Appointment Confirmation')
  end
end
# Improved email template formatting
# Updated subject line format
# Mobile-responsive OTP template
