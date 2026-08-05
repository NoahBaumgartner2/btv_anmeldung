# Erstellt automatisch einen Nachfolge-Kurs für den nächsten Term (Semester/
# Quartal), sobald Course#rollover_due? true ist. Genutzt von
# RolloverCoursePeriodsJob (täglich).
#
# Der alte Kurs bleibt unverändert als Archiv stehen (Registrierungen,
# Anwesenheiten, Trainings). Der neue Kurs übernimmt Titel, Trainer, Preis
# und alle übrigen Einstellungen 1:1, bekommt aber die Daten des nächsten
# Terms und frische Trainings – Wochentag/Zeit werden aus den bestehenden
# Trainings des alten Kurses übernommen (mehrere wöchentliche Slots möglich).
class CourseRolloverService
  def self.roll_over!(course)
    new(course).roll_over!
  end

  def initialize(course)
    @course = course
  end

  def roll_over!
    return unless @course.rollover_due?

    next_term = @course.next_term
    new_course = nil

    Course.transaction do
      new_course = @course.dup
      new_course.term = next_term
      new_course.start_date = next_term.start_date
      new_course.end_date = next_term.end_date
      new_course.previous_course = @course
      new_course.save!(validate: false)
      new_course.holiday_type_ids = @course.holiday_type_ids

      copy_trainers(new_course)
      generate_sessions(new_course)
    end

    notify_previous_participants(new_course)

    new_course
  end

  private

  # Informiert bisherige (nicht stornierte) Teilnehmende des alten Kurses,
  # dass sie sich für die neue Periode neu anmelden können.
  def notify_previous_participants(new_course)
    @course.course_registrations.where.not(status: "storniert")
           .select("DISTINCT ON (participant_id) *")
           .order(:participant_id, created_at: :desc)
           .each do |reg|
      CourseRegistrationMailer.renewal_available(reg, new_course).deliver_later
    end
  end

  def copy_trainers(new_course)
    @course.course_trainers.each do |ct|
      new_course.course_trainers.create!(trainer_id: ct.trainer_id, can_manually_enroll: ct.can_manually_enroll)
    end
  end

  def generate_sessions(new_course)
    patterns = weekly_patterns
    return if patterns.empty?

    holidays = Holiday.where(holiday_type_id: new_course.holiday_type_ids)
                       .where("start_date <= ? AND end_date >= ?", new_course.end_date, new_course.start_date)

    patterns.each do |wday, (start_h, start_m, end_h, end_m)|
      current_date = new_course.start_date.to_date
      while current_date <= new_course.end_date.to_date
        if current_date.wday == wday && holidays.none? { |h| current_date >= h.start_date && current_date <= h.end_date }
          full_start = current_date.in_time_zone.change(hour: start_h, min: start_m)
          full_end = end_h ? current_date.in_time_zone.change(hour: end_h, min: end_m) : nil
          new_course.training_sessions.create!(start_time: full_start, end_time: full_end)
        end
        current_date += 1.day
      end
    end
  end

  # Wochentag => [Start-Std, Start-Min, End-Std, End-Min], abgeleitet aus den
  # bestehenden (nicht abgesagten) Trainings des alten Kurses.
  def weekly_patterns
    @course.training_sessions.where(is_canceled: false).each_with_object({}) do |session, acc|
      wday = session.start_time.wday
      acc[wday] ||= [
        session.start_time.hour, session.start_time.min,
        session.end_time&.hour, session.end_time&.min
      ]
    end
  end
end
