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
PaymentSetting.destroy_all

puts "👤 Erstelle Benutzer (Admin, Trainer & Eltern)..."

# 👑 Der Admin-Account (Reto)
admin_user = User.create!(
  email: 'admin@btv.ch',
  password: 'password',
  password_confirmation: 'password',
  admin: true,
  confirmed_at: Time.current
)

# Ein normaler Trainer Account
trainer_user = User.create!(
  email: 'trainer@btv.ch',
  password: 'password',
  password_confirmation: 'password',
  confirmed_at: Time.current
)

# Zwei Eltern-Accounts
parent1 = User.create!(
  email: 'familie.meier@example.com',
  password: 'password',
  password_confirmation: 'password',
  confirmed_at: Time.current
)
parent2 = User.create!(
  email: 'familie.weber@example.com',
  password: 'password',
  password_confirmation: 'password',
  confirmed_at: Time.current
)

puts "🏋️ Erstelle Trainer-Profil..."
trainer1 = Trainer.create!(user: trainer_user, phone: '+41 79 123 45 67')

puts "👧👦 Erstelle Teilnehmer (Kinder)..."
child1 = Participant.create!(user: parent1, first_name: 'Mia',  last_name: 'Meier', date_of_birth: '2015-05-12', gender: 'weiblich',  phone_number: '+41 79 100 00 01')
child2 = Participant.create!(user: parent1, first_name: 'Leon', last_name: 'Meier', date_of_birth: '2017-08-22', gender: 'männlich', phone_number: '+41 79 100 00 02')
child3 = Participant.create!(user: parent2, first_name: 'Emma', last_name: 'Weber', date_of_birth: '2014-03-01', gender: 'weiblich',  phone_number: '+41 79 100 00 03')

puts "🤸 Erstelle Kurse..."

# Hilfsmethode: Training-Sessions für einen Kurs generieren (wie im Controller)
def generate_sessions(course, day_of_week:, start_hour:, start_min:, end_hour:, end_min:, holidays: [])
  current = course.start_date.to_date
  last    = course.end_date.to_date
  count   = 0

  while current <= last
    if current.wday == day_of_week
      in_holiday = holidays.any? { |h| current >= h.start_date && current <= h.end_date }
      unless in_holiday
        course.training_sessions.create!(
          start_time: current.in_time_zone.change(hour: start_hour, min: start_min),
          end_time:   current.in_time_zone.change(hour: end_hour,   min: end_min),
          is_canceled: false
        )
        count += 1
      end
    end
    current += 1.day
  end

  puts "   → #{count} Sessions erstellt (#{course.title})"
end

semester_start = Date.today.next_occurring(:monday)
semester_end   = semester_start + 5.months

# 1. Krabbel Gym – montags, Drop-In, Ticketing aktiv
krabbel_gym = Course.create!(
  title: 'Krabbel Gym',
  description: 'Wöchentliches Turnen für die Kleinsten. Bitte für jedes Training einzeln anmelden!',
  location: 'Turnhalle BTV',
  start_date: semester_start,
  end_date:   semester_start + 3.months,
  registration_type: 'pro_training',
  registration_mode: 'single_session',
  allows_holiday_deduction: false,
  has_ticketing: true,
  has_payment: false,
  default_start_hour: 9,  default_start_minute: 30,
  default_end_hour:   10, default_end_minute:   30
)

# 2. Kids Gym Kurse – Semester-Anmeldung
kids_gym_mi_morgen = Course.create!(
  title: 'Kids Gym (Mittwoch Morgen)',
  description: 'Semesterkurs für Kids. Einmalige Anmeldung sichert den Platz für das ganze Semester.',
  location: 'Turnhalle BTV',
  start_date: semester_start,
  end_date:   semester_end,
  registration_type: 'semester',
  registration_mode: 'semester',
  allows_holiday_deduction: true,
  has_ticketing: false,
  has_payment: false,
  max_participants: 12,
  default_start_hour: 9,  default_start_minute: 0,
  default_end_hour:   10, default_end_minute:   0
)

kids_gym_mi_nachmittag = Course.create!(
  title: 'Kids Gym (Mittwoch Nachmittag)',
  description: 'Semesterkurs für Kids. Einmalige Anmeldung sichert den Platz für das ganze Semester.',
  location: 'Turnhalle BTV',
  start_date: semester_start,
  end_date:   semester_end,
  registration_type: 'semester',
  registration_mode: 'semester',
  allows_holiday_deduction: true,
  has_ticketing: false,
  has_payment: false,
  max_participants: 12,
  default_start_hour: 15, default_start_minute: 0,
  default_end_hour:   16, default_end_minute:   0
)

kids_gym_do_morgen = Course.create!(
  title: 'Kids Gym (Donnerstag Morgen)',
  description: 'Semesterkurs für Kids. Einmalige Anmeldung sichert den Platz für das ganze Semester.',
  location: 'Turnhalle BTV',
  start_date: semester_start,
  end_date:   semester_end,
  registration_type: 'semester',
  registration_mode: 'semester',
  allows_holiday_deduction: true,
  has_ticketing: false,
  has_payment: false,
  max_participants: 12,
  default_start_hour: 9,  default_start_minute: 0,
  default_end_hour:   10, default_end_minute:   0
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


puts "📅 Generiere Trainings-Sessions..."
holidays = Holiday.all

generate_sessions(krabbel_gym,        day_of_week: 1, start_hour: 9,  start_min: 30, end_hour: 10, end_min: 30, holidays: holidays)
generate_sessions(kids_gym_mi_morgen,  day_of_week: 3, start_hour: 9,  start_min: 0,  end_hour: 10, end_min: 0,  holidays: holidays)
generate_sessions(kids_gym_mi_nachmittag, day_of_week: 3, start_hour: 15, start_min: 0,  end_hour: 16, end_min: 0,  holidays: holidays)
generate_sessions(kids_gym_do_morgen,  day_of_week: 4, start_hour: 9,  start_min: 0,  end_hour: 10, end_min: 0,  holidays: holidays)

puts "✅ Erstelle Anwesenheitsliste für vergangene Trainings..."
past_session_krabbel = krabbel_gym.training_sessions.where("start_time < ?", Time.current).order(:start_time).last
past_session_mi      = kids_gym_mi_morgen.training_sessions.where("start_time < ?", Time.current).order(:start_time).last

if past_session_krabbel
  Attendance.create!(training_session: past_session_krabbel, course_registration: reg3, status: 'anwesend')
end
if past_session_mi
  Attendance.create!(training_session: past_session_mi, course_registration: reg1, status: 'anwesend')
  Attendance.create!(training_session: past_session_mi, course_registration: reg2, status: 'abwesend')
end


puts "🏖️ Erstelle Feiertage..."
Holiday.create!(title: 'Sommerferien', start_date: '2026-07-06', end_date: '2026-08-09')

puts "💳 Erstelle SumUp Zahlungseinstellungen (Test-Platzhalter)..."
PaymentSetting.create!(
  sumup_api_key:               "sup_sk_dev_placeholder",
  sumup_access_token:          "test_access_token_placeholder",
  sumup_merchant_code:         "MDEV0001",
  currency:                    "chf",
  active:                      false
)

puts "🎉 Fertig! Datenbank ist nun mit BTV Dummy-Daten gefüllt."
