class NotificationService
  def self.create(user:, title:, message:, notification_type:, reference_id: nil, reference_type: nil, send_email: false)
    notification = Notification.create!(
      user: user,
      title: title,
      message: message,
      notification_type: notification_type,
      reference_id: reference_id,
      reference_type: reference_type
    )

    # Send email notification if requested
    if send_email && user.email.present?
      NotificationMailer.send_notification(user, title, message).deliver_later rescue NotificationMailer.send_notification(user, title, message).deliver_now
    end

    notification
  end

  def self.notify_appointment_booked(appointment)
    user = appointment.patient.user
    create(
      user: user,
      title: 'Appointment Booked',
      message: "Your appointment has been booked. Priority: #{appointment.priority_level}, Score: #{appointment.priority_score}/100. You are now in the priority queue.",
      notification_type: 'appointment_booked',
      reference_id: appointment.id,
      reference_type: 'Appointment',
      send_email: true
    )
  end

  def self.notify_appointment_approved(appointment)
    user = appointment.patient.user
    slot = appointment.time_slot
    time_info = slot ? " Scheduled for #{slot.start_time.strftime('%B %d at %I:%M %p')}." : ""
    create(
      user: user,
      title: 'Appointment Approved',
      message: "Your appointment has been approved by the receptionist.#{time_info}",
      notification_type: 'appointment_approved',
      reference_id: appointment.id,
      reference_type: 'Appointment',
      send_email: true
    )
  end

  def self.notify_appointment_rejected(appointment, reason = nil)
    user = appointment.patient.user
    msg = "Your appointment request has been reviewed."
    msg += " Reason: #{reason}" if reason.present?
    msg += " Please contact the front desk for assistance."
    create(
      user: user,
      title: 'Appointment Update',
      message: msg,
      notification_type: 'appointment_rejected',
      reference_id: appointment.id,
      reference_type: 'Appointment',
      send_email: true
    )
  end

  def self.notify_priority_change(appointment, old_level, new_level)
    user = appointment.patient.user
    create(
      user: user,
      title: 'Priority Updated',
      message: "Your priority level has been updated from #{old_level} to #{new_level} by a receptionist.",
      notification_type: 'priority_change',
      reference_id: appointment.id,
      reference_type: 'Appointment',
      send_email: true
    )
  end

  def self.notify_schedule_update(appointment)
    user = appointment.patient.user
    slot = appointment.time_slot
    return unless slot
    create(
      user: user,
      title: 'Schedule Updated',
      message: "Your appointment has been rescheduled to #{slot.start_time.strftime('%B %d at %I:%M %p')}.",
      notification_type: 'schedule_update',
      reference_id: appointment.id,
      reference_type: 'Appointment',
      send_email: true
    )
  end

  def self.log_activity(user:, action:, details: nil, ip_address: nil, resource_type: nil, resource_id: nil)
    ActivityLog.create(
      user: user,
      action: action,
      details: details,
      ip_address: ip_address,
      resource_type: resource_type,
      resource_id: resource_id
    )
  end
end
# TODO: Move to ActiveJob for async delivery
