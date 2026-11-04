# Kurse und Trainings einer Person mit Anwesenheit, für die Admin-Detailseite.
# Rein lesend. Es wird nur ausgewiesen, was sich belegen lässt:
#   - Normale Kurse: kein Eintrag bedeutet anwesend, aber erst wenn der Trainer das
#     Training bestätigt hat. Davor gilt es als "nicht erfasst".
#   - Drop-in (QR-Ticketing): kein Eintrag bedeutet abwesend, ebenfalls nach Bestätigung.
#   - Stornierte Anmeldungen zeigen nur Einträge: Das Storno-Datum ist nicht gespeichert,
#     die Teilnahme davor lässt sich also nicht ableiten.
class ParticipantAttendanceHistory
  Row = Struct.new(:session, :status, :reason, keyword_init: true)
  Entry = Struct.new(:course, :registration, :moved_to, :rows, :sessions_before_move, keyword_init: true) do
    def count(status) = rows.count { |row| row.status == status }
    def recorded_count = count(:present) + count(:absent) + count(:excused)
    def upcoming? = count(:planned).positive?
    # Beendete, stornierte und verschobene Kurse gehören ins Archiv.
    def active? = registration.present? && registration.status != "storniert" && !course.ended?
  end

  # Ein Eintrag schlägt die aus dem Kursplan abgeleiteten Zeilen, falls zwei Anmeldungen
  # derselben Person dasselbe Training betreffen.
  def self.call(participant)
    registrations = participant.course_registrations
                               .includes(:course, :training_session, :trial_session,
                                         attendances: { training_session: :course })
                               .to_a
    planned = TrainingSession.where(course_id: registrations.map(&:course_id).uniq)
                             .where.not(start_time: nil).includes(:course).group_by(&:course_id)

    rows_by_session = {}
    registrations.each do |registration|
      expected_sessions(registration, planned).each do |session|
        rows_by_session[session.id] ||= build_row(session, nil)
      end
    end
    registrations.each do |registration|
      registration.attendances.each do |attendance|
        next if attendance.status.blank? || attendance.training_session.start_time.nil?

        rows_by_session[attendance.training_session_id] = build_row(attendance.training_session, attendance)
      end
    end

    rows_by_course = rows_by_session.values.group_by { |row| row.session.course }
    courses = (registrations.map(&:course) + rows_by_course.keys).uniq

    courses.map { |course| build_entry(course, registrations, rows_by_course.fetch(course, [])) }
           .sort_by { |entry| [ entry.upcoming? ? 0 : 1, -last_activity(entry).to_i ] }
  end

  def self.expected_sessions(registration, planned)
    case registration.status
    when "schnuppern"
      [ registration.trial_session || registration.training_session ].compact.select(&:start_time)
    when "bestätigt"
      return [] if registration.abo_entries_total.present?
      return [ registration.training_session ].compact.select(&:start_time) if registration.training_session_id

      from = registration.moved_at || registration.enrolled_at || registration.created_at
      planned.fetch(registration.course_id, []).select { |session| session.start_time >= from }
    else
      []
    end
  end
  private_class_method :expected_sessions

  def self.build_row(session, attendance)
    Row.new(session: session, status: row_status(session, attendance),
            reason: session.cancellation_reason.presence || attendance&.cancellation_reason)
  end
  private_class_method :build_row

  def self.row_status(session, attendance)
    return :cancelled if session.is_canceled? || attendance&.training_cancelled?

    case attendance&.status
    when "anwesend" then :present
    when "abwesend" then :absent
    when "abgemeldet" then :excused
    else
      if session.start_time > Time.current then :planned
      elsif !session.attendance_confirmed? then :unrecorded
      elsif session.course.has_ticketing? then :absent
      else :present
      end
    end
  end
  private_class_method :row_status

  def self.build_entry(course, registrations, rows)
    own = registrations.select { |registration| registration.course_id == course.id }
    registration = (own.reject { |r| r.status == "storniert" }.presence || own).max_by(&:created_at)
    moved_to = registration ? nil : moved_target(course, registrations)
    Entry.new(course: course, registration: registration, moved_to: moved_to,
              rows: rows.sort_by { |row| row.session.start_time },
              sessions_before_move: registration&.sessions_before_move.to_i)
  end
  private_class_method :build_entry

  def self.moved_target(course, registrations)
    registrations.find { |r| r.attendances.any? { |a| a.training_session.course_id == course.id } }&.course
  end
  private_class_method :moved_target

  def self.last_activity(entry)
    entry.rows.last&.session&.start_time || entry.course.start_date&.to_time
  end
  private_class_method :last_activity
end
