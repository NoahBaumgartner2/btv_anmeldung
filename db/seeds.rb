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

puts "👤 Erstelle Benutzer (Admin, Trainer & Eltern)..."

# 👑 Der Admin-Account (Reto)
admin_user = User.create!(
  email: 'admin@btv.ch', 
  password: 'password', 
  password_confirmation: 'password', 
  admin: true
)

# Ein normaler Trainer Account
trainer_user = User.create!(
  email: 'trainer@btv.ch', 
  password: 'password', 
  password_confirmation: 'password'
)

# Zwei Eltern-Accounts
parent1 = User.create!(
  email: 'familie.meier@example.com', 
  password: 'password', 
  password_confirmation: 'password'
)
parent2 = User.create!(
  email: 'familie.weber@example.com', 
  password: 'password', 
  password_confirmation: 'password'
)

puts "🏋️ Erstelle Trainer-Profil..."
trainer1 = Trainer.create!(user: trainer_user, phone: '+41 79 123 45 67')

puts "👧👦 Erstelle Teilnehmer (Kinder)..."
child1 = Participant.create!(user: parent1, first_name: 'Mia', last_name: 'Meier', date_of_birth: '2015-05-12', gender: 'weiblich')
child2 = Participant.create!(user: parent1, first_name: 'Leon', last_name: 'Meier', date_of_birth: '2017-08-22', gender: 'männlich')
child3 = Participant.create!(user: parent2, first_name: 'Emma', last_name: 'Weber', date_of_birth: '2014-03-01', gender: 'weiblich')

puts "🤸 Erstelle Kurse..."

# 1. Krabbel Gym (Drop-In, Wöchentlich neu anmelden, Ticketing aktiv)
krabbel_gym = Course.create!(
  title: 'Krabbel Gym',
  description: 'Wöchentliches Turnen für die Kleinsten. Bitte für jedes Training einzeln anmelden!',
  location: 'Turnhalle BTV',
  start_date: 1.week.from_now,
  end_date: 3.months.from_now,
  registration_type: 'pro_training',
  registration_mode: 'single_session', # Drop-In Anmeldung
  allows_holiday_deduction: false,
  has_ticketing: true, # Hat digitale Tickets!
  has_payment: true
)

# 2. Kids Gym Kurse (Semester-Anmeldung, Kein Ticketing, Bezahlung pro Semester)
kids_gym_mi_morgen = Course.create!(
  title: 'Kids Gym (Mittwoch Morgen)',
  description: 'Semesterkurs für Kids. Einmalige Anmeldung sichert den Platz für das ganze Semester.',
  location: 'Turnhalle BTV',
  start_date: 1.week.from_now,
  end_date: 6.months.from_now,
  registration_type: 'semester',
  registration_mode: 'semester', # Einmalige Anmeldung
  allows_holiday_deduction: true,
  has_ticketing: false, # Ohne Tickets
  has_payment: true
)

kids_gym_mi_nachmittag = Course.create!(
  title: 'Kids Gym (Mittwoch Nachmittag)',
  description: 'Semesterkurs für Kids. Einmalige Anmeldung sichert den Platz für das ganze Semester.',
  location: 'Turnhalle BTV',
  start_date: 1.week.from_now,
  end_date: 6.months.from_now,
  registration_type: 'semester',
  registration_mode: 'semester',
  allows_holiday_deduction: true,
  has_ticketing: false,
  has_payment: true
)

kids_gym_do_morgen = Course.create!(
  title: 'Kids Gym (Donnerstag Morgen)',
  description: 'Semesterkurs für Kids. Einmalige Anmeldung sichert den Platz für das ganze Semester.',
  location: 'Turnhalle BTV',
  start_date: 1.week.from_now,
  end_date: 6.months.from_now,
  registration_type: 'semester',
  registration_mode: 'semester',
  allows_holiday_deduction: true,
  has_ticketing: false,
  has_payment: true
)


puts "🔗 Weise Trainer den Kursen zu..."
CourseTrainer.create!(course: krabbel_gym, trainer: trainer1)
CourseTrainer.create!(course: kids_gym_mi_morgen, trainer: trainer1)


puts "📝 Erstelle Kurs-Anmeldungen..."
# Mia (child1) und Leon (child2) melden sich für das Semester Kids Gym an
reg1 = CourseRegistration.create!(course: kids_gym_mi_morgen, participant: child1, status: 'bestätigt', payment_cleared: true, holiday_deduction_claimed: false)
reg2 = CourseRegistration.create!(course: kids_gym_mi_morgen, participant: child2, status: 'bestätigt', payment_cleared: false, holiday_deduction_claimed: false)

# Emma (child3) meldet sich für das Krabbel Gym (Einzeltermin) an
reg3 = CourseRegistration.create!(course: krabbel_gym, participant: child3, status: 'bestätigt', payment_cleared: true, holiday_deduction_claimed: false)


puts "📅 Erstelle Trainings-Sessions..."
# Wir erstellen beispielhaft Sessions für das Krabbel Gym und Kids Gym
session1 = TrainingSession.create!(course: krabbel_gym, start_time: 1.week.from_now.change(hour: 9, min: 30), end_time: 1.week.from_now.change(hour: 10, min: 30), is_canceled: false)
session2 = TrainingSession.create!(course: kids_gym_mi_morgen, start_time: 1.week.from_now.change(hour: 10, min: 00), end_time: 1.week.from_now.change(hour: 11, min: 00), is_canceled: false)


puts "✅ Erstelle Anwesenheitsliste für die ersten Trainings..."
Attendance.create!(training_session: session1, course_registration: reg3, status: 'anwesend') # Emma beim Krabbel Gym
Attendance.create!(training_session: session2, course_registration: reg1, status: 'anwesend') # Mia beim Kids Gym
Attendance.create!(training_session: session2, course_registration: reg2, status: 'entschuldigt') # Leon ist krank beim Kids Gym


puts "🏖️ Erstelle Feiertage..."
Holiday.create!(title: 'Sommerferien', start_date: '2026-07-06', end_date: '2026-08-09')

puts "🎉 Fertig! Datenbank ist nun mit BTV Dummy-Daten gefüllt."