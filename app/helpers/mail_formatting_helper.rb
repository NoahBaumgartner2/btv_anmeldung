module MailFormattingHelper
  # Persönliche Anrede: User#first_name → Trainer#first_name → E-Mail-Präfix
  def greeting_name(user)
    return "" if user.nil?
    name = user.try(:first_name).presence
    name ||= user.try(:trainer)&.first_name.presence
    name ||= user.email.to_s.split("@").first
    name
  end

  # "Donnerstag, 4. Juni 2026, 19:00 – 20:30 Uhr" bei gleichem Tag,
  # sonst "Do, 4. Juni 2026, 19:00 Uhr – Fr, 5. Juni 2026, 09:00 Uhr".
  def format_session_range(start_time, end_time)
    return I18n.l(start_time, format: :long) if end_time.blank?

    if start_time.to_date == end_time.to_date
      "#{I18n.l(start_time.to_date, format: :long_day)}, " \
        "#{start_time.strftime('%H:%M')} – #{end_time.strftime('%H:%M')} Uhr"
    else
      "#{I18n.l(start_time, format: :long)} – #{I18n.l(end_time, format: :long)}"
    end
  end
end
