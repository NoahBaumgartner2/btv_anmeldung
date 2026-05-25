puts "🧹 Räume Datenbank auf..."
Attendance.destroy_all
TrainingSession.destroy_all
CourseRegistration.destroy_all
CourseTrainer.destroy_all
Trainer.destroy_all
Course.destroy_all
Participant.destroy_all
User.where.not(admin: true).destroy_all
Holiday.destroy_all
PaymentSetting.destroy_all

puts "👤 Erstelle Admin-Benutzer..."
admin = User.find_or_initialize_by(email: 'admin@btv.com')
admin.assign_attributes(
  password: 'password',
  password_confirmation: 'password',
  confirmed_at: Time.current,
  admin: true,
  privacy_accepted: true
)
admin.save!

puts "✅ Fertig! Nur Admin-Login vorhanden. Du kannst nun mit der Kurserfassung beginnen."
puts "   E-Mail:    admin@btv.com"
puts "   Passwort:  password"
