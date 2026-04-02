class NewsletterSubscriber < ApplicationRecord
  STATUSES = %w[subscribed unsubscribed].freeze
  SOURCES  = %w[manual csv_import].freeze

  validates :email,  presence: true, uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }

  before_save { self.email = email.downcase.strip }

  scope :subscribed,   -> { where(status: "subscribed") }
  scope :unsubscribed, -> { where(status: "unsubscribed") }

  def subscribed? = status == "subscribed"
end
