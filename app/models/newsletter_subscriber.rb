class NewsletterSubscriber < ApplicationRecord
  STATUSES = %w[subscribed unsubscribed].freeze
  SOURCES  = %w[manual csv_import registration].freeze

  validates :email,  presence: true, uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }

  before_create { self.unsubscribe_token = SecureRandom.urlsafe_base64(32) }
  before_save { self.email = email.downcase.strip }

  after_commit  :sync_to_infomaniak,           on: [ :create, :update ]
  after_destroy_commit :unsubscribe_from_infomaniak

  scope :subscribed,   -> { where(status: "subscribed") }
  scope :unsubscribed, -> { where(status: "unsubscribed") }

  def subscribed? = status == "subscribed"

  private

  def unsubscribe_from_infomaniak
    InfomaniakUnsubscribeJob.perform_later(email)
  rescue => e
    Rails.logger.error "[NewsletterSubscriber] Infomaniak-Unsubscribe fehlgeschlagen (#{email}): #{e.message}"
  end

  def sync_to_infomaniak
    return unless saved_change_to_status? || saved_change_to_email? || saved_change_to_name?

    if saved_change_to_email?
      old_email = saved_changes["email"].first
      InfomaniakUnsubscribeJob.perform_later(old_email) if old_email.present?
    end

    if subscribed?
      InfomaniakSubscribeJob.perform_later(email, name: name)
    elsif saved_change_to_status?
      InfomaniakUnsubscribeJob.perform_later(email)
    end
  rescue => e
    Rails.logger.error "[NewsletterSubscriber] Infomaniak-Sync fehlgeschlagen (#{email}): #{e.message}"
  end
end
