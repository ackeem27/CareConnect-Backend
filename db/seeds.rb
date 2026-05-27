# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding CareConnect database..."

# ── Default Staff Accounts ──
admin = User.find_or_create_by!(email: 'admin@careconnect.com') do |u|
  u.password = 'Admin123!'
  u.password_confirmation = 'Admin123!'
  u.role = 'admin'
  u.name = 'System Administrator'
  u.email_verified = true
  u.active = true
end
puts "  ✅ Admin: admin@careconnect.com / Admin123!"

doctor = User.find_or_create_by!(email: 'doctor@careconnect.com') do |u|
  u.password = 'Doctor123!'
  u.password_confirmation = 'Doctor123!'
  u.role = 'doctor'
  u.name = 'Dr. Sarah Jenkins'
  u.email_verified = true
  u.active = true
end
puts "  ✅ Doctor: doctor@careconnect.com / Doctor123!"

doctor2 = User.find_or_create_by!(email: 'dr.chen@careconnect.com') do |u|
  u.password = 'Doctor123!'
  u.password_confirmation = 'Doctor123!'
  u.role = 'doctor'
  u.name = 'Dr. Chen'
  u.email_verified = true
  u.active = true
end
puts "  ✅ Doctor: dr.chen@careconnect.com / Doctor123!"

receptionist = User.find_or_create_by!(email: 'receptionist@careconnect.com') do |u|
  u.password = 'Receptionist123!'
  u.password_confirmation = 'Receptionist123!'
  u.role = 'receptionist'
  u.name = 'Reception Desk'
  u.email_verified = true
  u.active = true
end
puts "  ✅ Receptionist: receptionist@careconnect.com / Receptionist123!"

# ── Default System Configurations ──
[
  { key: 'slot_duration_minutes', value: '30', description: 'Duration of each appointment slot in minutes' },
  { key: 'working_hours_start', value: '08:00', description: 'Start of working hours (HH:MM)' },
  { key: 'working_hours_end', value: '17:00', description: 'End of working hours (HH:MM)' },
  { key: 'max_patients_per_day', value: '40', description: 'Maximum patients per day' },
  { key: 'auto_approve_low_priority', value: 'false', description: 'Auto-approve LOW priority appointments' },
  { key: 'email_notifications_enabled', value: 'true', description: 'Enable email notifications' },
].each do |config|
  SystemConfig.find_or_create_by!(key: config[:key]) do |c|
    c.value = config[:value]
    c.description = config[:description]
  end
end
puts "  ✅ System configs seeded"

# ── Log seeding activity ──
ActivityLog.create!(
  user: admin,
  action: 'system_event',
  details: 'Database seeded with default staff accounts and configurations'
)
puts "  ✅ Activity log created"

puts "✨ Seeding complete!"
