class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable, :lockable

  has_many :participants, dependent: :destroy
  has_one :trainer, dependent: :destroy

  attr_accessor :privacy_accepted, :devise_notification_error
  validates :privacy_accepted, acceptance: { allow_nil: false }, on: :create

  validates :phone_number, :street, :zip_code, :city,
            presence: true,
            if: :family_data_completed?

  before_create :set_privacy_accepted_at

  def needs_onboarding?
    return false if admin? || Trainer.exists?(user: self)
    !family_data_completed?
  end

  def family_defaults
    {
      phone_number: phone_number,
      street: street,
      house_number: house_number,
      zip_code: zip_code,
      city: city,
      country: country.presence || "CH",
      nationality: nationality.presence || "CH",
      mother_tongue: mother_tongue.presence || "DE"
    }
  end

  def newsletter_subscriber
    NewsletterSubscriber.find_by(email: email.downcase.strip)
  end

  def newsletter_subscribed?
    newsletter_subscriber&.subscribed? || false
  end

  def send_devise_notification(notification, *args)
    super
  rescue Net::SMTPAuthenticationError, Net::SMTPServerBusy,
         Net::SMTPSyntaxError, Net::SMTPFatalError,
         Errno::ECONNREFUSED, SocketError, Timeout::Error => e
    Rails.logger.error "[Devise Mailer] #{e.class}: #{e.message}"
    self.devise_notification_error = e
  end

  private

  def set_privacy_accepted_at
    self.privacy_accepted_at = Time.current if privacy_accepted.in?([ "1", true ])
  end
end