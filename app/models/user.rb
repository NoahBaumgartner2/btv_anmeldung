class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  # Ein User (Elternteil) kann mehrere Teilnehmer (Kinder) verwalten:
  has_many :participants, dependent: :destroy

  has_one :trainer, dependent: :destroy

  attr_accessor :subscribe_to_newsletter

  after_create :handle_newsletter_subscription

  private

  def handle_newsletter_subscription
    return unless subscribe_to_newsletter == "1"

    NewsletterSubscriber.find_or_initialize_by(email: email.downcase.strip).tap do |sub|
      sub.status = "subscribed"
      sub.source = "manual"
      sub.save
    end
  end
end