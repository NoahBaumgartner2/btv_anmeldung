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

reto = User.find_or_initialize_by(email: 'reto.marthaler@btvbern.ch')
reto.assign_attributes(
  password: 'password',
  password_confirmation: 'password',
  confirmed_at: Time.current,
  admin: true,
  privacy_accepted: true
)
reto.save!

Celine = User.find_or_initialize_by(email: 'cediethelm@hotmail.com')
Celine.assign_attributes(
  password: 'password',
  password_confirmation: 'password',
  confirmed_at: Time.current,
  admin: true,
  privacy_accepted: true
)
Celine.save!

Christoph = User.find_or_initialize_by(email: 'schaerer_ch@bluewin.ch')
Christoph.assign_attributes(
  password: 'password',
  password_confirmation: 'password',
  confirmed_at: Time.current,
  admin: true,
  privacy_accepted: true
)
Christoph.save!

Jasmin = User.find_or_initialize_by(email: 'jasmin.rosaabreu@gmail.com')
Jasmin.assign_attributes(
  password: 'password',
  password_confirmation: 'password',
  confirmed_at: Time.current,
  admin: true,
  privacy_accepted: true
)
Jasmin.save!

Michele = User.find_or_initialize_by(email: 'michele.lorethan@bluewin.ch')
Michele.assign_attributes(
  password: 'password',
  password_confirmation: 'password',
  confirmed_at: Time.current,
  admin: true,
  privacy_accepted: true
)
Michele.save!


puts "Admin accounts created"
