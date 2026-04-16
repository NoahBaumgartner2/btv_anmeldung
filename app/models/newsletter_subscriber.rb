class NewsletterSubscriber < ApplicationRecord
  STATUSES = %w[subscribed unsubscribed].freeze
  SOURCES  = %w[manual csv_import].freeze

  validates :email,  presence: true, uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }

  before_save { self.email = email.downcase.strip }

  after_commit  :sync_to_infomaniak,           on: [ :create, :update ]
  after_destroy_commit :unsubscribe_from_infomaniak

  scope :subscribed,   -> { where(status: "subscribed") }
  scope :unsubscribed, -> { where(status: "unsubscribed") }

  def subscribed? = status == "subscribed"

  private

  def unsubscribe_from_infomaniak
    InfomaniakUnsubscribeJob.perform_later(email) if subscribed?
  end

  def sync_to_infomaniak
    return unless saved_change_to_status? || saved_change_to_email? || saved_change_to_name?

    # E-Mail geändert: alte Adresse bei Infomaniak austragen, damit keine Dublette entsteht.
    if saved_change_to_email?
      old_email = saved_changes["email"].first
      InfomaniakUnsubscribeJob.perform_later(old_email) if old_email.present?
    end

    if subscribed?
      # (Re-)Subscribe mit aktueller E-Mail und aktuellem Namen –
      # deckt: Neu-Eintrag, Status-Wechsel zu subscribed, E-Mail- und Name-Änderungen.
      InfomaniakSubscribeJob.perform_later(email, name: name)
    elsif saved_change_to_status?
      # Nur bei explizitem Status-Wechsel zu "unsubscribed" austragen.
      # Bei reiner E-Mail-Änderung eines bereits unsubscribed Records feuert hier nichts –
      # die neue Adresse war nie eingetragen.
      InfomaniakUnsubscribeJob.perform_later(email)
    end
  end
end
