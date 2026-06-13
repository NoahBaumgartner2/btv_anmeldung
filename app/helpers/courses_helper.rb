module CoursesHelper
  # Wochentag + Zeitbereich der repräsentativen Session, z.B. "Montag, 17:00–18:30".
  # Gibt nil zurück, wenn keine Session existiert oder Drop-In-Sessions an
  # unterschiedlichen Wochentagen/Zeiten stattfinden (kein irreführender Einzeltag).
  def course_weekly_time(course)
    session = course.representative_session
    return nil unless session

    if course.registration_mode == "single_session"
      patterns = course.training_sessions
                       .reject(&:is_canceled)
                       .select { |s| s.start_time.present? }
                       .map { |s| [ s.start_time.in_time_zone.wday, s.start_time.in_time_zone.strftime("%H:%M"), s.end_time&.in_time_zone&.strftime("%H:%M") ] }
                       .uniq
      return nil if patterns.size > 1
    end

    start = session.start_time.in_time_zone
    day   = I18n.t("date.day_names")[start.wday]
    time  = start.strftime("%H:%M")
    time += "–#{session.end_time.in_time_zone.strftime('%H:%M')}" if session.end_time.present?
    "#{day}, #{time}"
  end
end
