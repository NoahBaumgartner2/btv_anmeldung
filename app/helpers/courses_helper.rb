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

  # Alle eindeutigen Orte einer Kurssammlung, z.B. ["ewb-Halle", "Turnhalle Brunnmatt (Halle 3)"].
  def category_locations(courses)
    courses.map(&:location).compact_blank.uniq
  end

  # Wochentag-Index (0=So .. 6=Sa) der repräsentativen Session eines Kurses.
  # nil, wenn keine eindeutige Aussage möglich ist (keine Session oder Drop-In
  # mit gemischten Wochentagen) – analog zur Logik in course_weekly_time.
  def course_weekday_index(course)
    session = course.representative_session
    return nil unless session&.start_time

    if course.registration_mode == "single_session"
      wdays = course.training_sessions
                    .reject(&:is_canceled)
                    .filter_map { |s| s.start_time&.in_time_zone&.wday }
                    .uniq
      return nil if wdays.size > 1
    end

    session.start_time.in_time_zone.wday
  end

  # Sortierte, eindeutige Wochentagsnamen einer Kurssammlung (Montag zuerst),
  # z.B. ["Montag", "Mittwoch"].
  def category_weekday_names(courses)
    courses.filter_map { |c| course_weekday_index(c) }
           .uniq
           .sort_by { |wday| (wday - 1) % 7 }
           .map { |wday| I18n.t("date.day_names")[wday] }
  end
  # Für die Kurskarte: ["Mo", "17:00–18:00"] oder nil. Gleiche Regeln wie
  # course_weekly_time (Drop-In mit gemischten Zeiten → nil).
  def course_day_and_time(course)
    text = course_weekly_time(course) or return nil
    wday = course_weekday_index(course) or return nil
    [ I18n.t("date.abbr_day_names")[wday], text.split(", ", 2).last ] # ponytail: Format "Tag, Zeit" aus course_weekly_time
  end

  # Alle Wochentage (0=So..6=Sa), an denen der Kurs Trainings hat – für den
  # Tag-Filter, damit Drop-Ins mit mehreren Tagen bei jedem Tag erscheinen.
  def course_weekdays(course)
    days = course.training_sessions.reject(&:is_canceled).filter_map { |s| s.start_time&.in_time_zone&.wday }.uniq
    days.presence || [ course_weekday_index(course) ].compact
  end
end
