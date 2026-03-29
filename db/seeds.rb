puts "🧹 Räume Datenbank auf..."
Attendance.destroy_all
TrainingSession.destroy_all
CourseRegistration.destroy_all
CourseTrainer.destroy_all
Trainer.destroy_all
Course.destroy_all
Participant.destroy_all
User.destroy_all
Holiday.destroy_all

puts "👤 Erstelle Benutzer (Eltern & Trainer)..."
# Ein Admin/Trainer Account
trainer_user = User.create!(email: 'trainer@btv.ch', password: 'password', password_confirmation: 'password')
# Zwei Eltern-Accounts
parent1 = User.create!(email: 'familie.meier@example.com', password: 'password', password_confirmation: 'password')
parent2 = User.create!(email: 'familie.weber@example.com', password: 'password', password_confirmation: 'password')

puts "🏋️ Erstelle Trainer-Profil..."
trainer1 = Trainer.create!(user: trainer_user, phone: '+41 79 123 45 67')

puts "👧👦 Erstelle Teilnehmer (Kinder)..."
child1 = Participant.create!(user: parent1, first_name: 'Mia', last_name: 'Meier', date_of_birth: '2015-05-12', gender: 'weiblich')
child2 = Participant.create!(user: parent1, first_name: 'Leon', last_name: 'Meier', date_of_birth: '2017-08-22', gender: 'männlich')
child3 = Participant.create!(user: parent2, first_name: 'Emma', last_name: 'Weber', date_of_birth: '2014-03-01', gender: 'weiblich')

puts "🤸 Erstelle Kurse..."
course1 = Course.create!(
  title: 'Geräteturnen Kids (Sommer)',
  description: 'Einsteigerkurs für Geräteturnen. Fokus auf Boden und Reck.',
  location: 'Turnhalle BTV',
  start_date: 1.week.from_now,
  end_date: 3.months.from_now,
  registration_type: 'pro_training',
  allows_holiday_deduction: true,
  has_ticketing: false,
  has_payment: true
)

course2 = Course.create!(
  title: 'Leichtathletik Camp',
  description: 'Intensivwoche in den Sommerferien für alle Altersklassen.',
  location: 'Sportplatz',
  start_date: 2.months.from_now,
  end_date: 2.months.from_now + 1.week,
  registration_type: 'einmalig',
  allows_holiday_deduction: false,
  has_ticketing: true,
  has_payment: true
)

puts "🔗 Weise Trainer den Kursen zu..."
CourseTrainer.create!(course: course1, trainer: trainer1)
CourseTrainer.create!(course: course2, trainer: trainer1)

puts "📝 Erstelle Kurs-Anmeldungen..."
reg1 = CourseRegistration.create!(course: course1, participant: child1, status: 'bestätigt', payment_cleared: true, holiday_deduction_claimed: false)
reg2 = CourseRegistration.create!(course: course1, participant: child2, status: 'bestätigt', payment_cleared: false, holiday_deduction_claimed: false)
reg3 = CourseRegistration.create!(course: course2, participant: child3, status: 'warteliste', payment_cleared: false, holiday_deduction_claimed: false)

puts "📅 Erstelle Trainings-Sessions für Kurs 1..."
session1 = TrainingSession.create!(course: course1, start_time: 1.week.from_now.change(hour: 18), end_time: 1.week.from_now.change(hour: 19, min: 30), is_canceled: false)
session2 = TrainingSession.create!(course: course1, start_time: 2.weeks.from_now.change(hour: 18), end_time: 2.weeks.from_now.change(hour: 19, min: 30), is_canceled: false)

puts "✅ Erstelle Anwesenheitsliste für das erste Training..."
Attendance.create!(training_session: session1, course_registration: reg1, status: 'anwesend')
Attendance.create!(training_session: session1, course_registration: reg2, status: 'entschuldigt')

puts "🏖️ Erstelle Feiertage..."
Holiday.create!(title: 'Sommerferien', start_date: '2026-07-06', end_date: '2026-08-09')

puts "🎉 Fertig! Datenbank ist nun mit BTV Dummy-Daten gefüllt."