# Eine versendete Mail mit ihrem HTML-Inhalt (für die Vorschau „was genau gesendet
# wurde“; Einträge vor Nov. 2026 haben keinen Inhalt). trainer_ids hält fest, wer beim Versand für den Kurs
# oder das Training eingeteilt war: Spätere Wechsel ändern nichts daran, wer sie sieht.
class MailLog < ApplicationRecord
  # Aufbewahrungsdauer, einstellbar unter Einstellungen › Funktionen & Regeln.
  def self.retention = FeatureSetting.value(:mail_log_retention_months).months

  # Was Trainer:innen sehen dürfen. Neue Mailarten sind automatisch nur für Admins sichtbar,
  # genau wie Zahlungs-, Rückerstattungs- und interne Admin-Mails.
  TRAINER_VISIBLE_KINDS = %w[
    course_registration.confirmation
    course_registration.waitlist_promoted
    course_registration.cancelled_by_trainer
    course_registration.abo_imported
    course_registration.renewal_available
    course_registration.abo_exhausted
    course_registration.trial_expired
    course_registration.trial_date_changed
    course_registration.self_cancelled
    course_registration.trainer_cancel_notice
    course_registration.custom_message
    course_registration.status_changed
    course_registration.manual_enrollment_reminder
    training_session.cancellation_notice
    training_session.unsubscribe_reminder
    training_session.substitute_assigned
    attendance_reminder.trainer_reminder
    participant.complete_profile
    course_trainer.assigned_to_course
  ].freeze

  scope :visible_to, ->(user) {
    next all if user.admin?

    trainer = Trainer.find_by(user: user)
    next none unless trainer

    where(kind: TRAINER_VISIBLE_KINDS).where("trainer_ids @> ARRAY[?]::bigint[]", trainer.id)
  }

  def self.record(kind:, message:, course:, session:, participant:, parent:)
    recipients = Array(message.to)
    create!(
      kind: kind, subject: message.subject, recipients: recipients,
      from_address: message[:from].to_s, html_body: html_content(message),
      audience: audience_for(recipients, parent || participant&.user),
      course_id: course&.id, course_title: course&.title,
      training_session_id: session&.id, session_start: session&.start_time,
      participant_id: participant&.id, participant_name: participant && "#{participant.first_name} #{participant.last_name}".strip,
      trainer_ids: ((course&.trainer_ids || []) + [ session&.substitute_trainer_id ]).compact.uniq
    )
  end

  # HTML der Mail wie im Postfach; reine Textmails als vorformatierter Text.
  def self.html_content(message)
    return message.html_part.decoded if message.html_part
    return message.decoded if message.mime_type == "text/html"

    text = (message.text_part || message).decoded
    %(<pre style="white-space:pre-wrap;font:14px/1.6 Arial,Helvetica,sans-serif;margin:24px;color:#111827">#{ERB::Util.html_escape(text)}</pre>)
  end
  private_class_method :html_content

  def self.audience_for(recipients, parent)
    if parent.respond_to?(:email) && recipients.include?(parent.email) then "parent"
    elsif Trainer.joins(:user).exists?(users: { email: recipients }) then "trainer"
    elsif User.exists?(email: recipients, admin: true) then "admin"
    else "other"
    end
  end
  private_class_method :audience_for

  # search_all: Admins suchen auch in Betreff und Adressen, Trainer:innen nur in Namen und Kurs.
  def self.search(query, search_all:)
    pattern = "%#{sanitize_sql_like(query)}%"
    columns = %w[participant_name course_title]
    columns += [ "subject", "array_to_string(recipients, ' ')" ] if search_all
    where(columns.map { |column| "#{column} ILIKE :pattern" }.join(" OR "), pattern: pattern)
  end

  def label
    I18n.t("mail_logs.kinds.#{kind}", default: kind.humanize)
  end
end
