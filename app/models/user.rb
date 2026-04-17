class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable, :lockable

  # Ein User (Elternteil) kann mehrere Teilnehmer (Kinder) verwalten:
  has_many :participants, dependent: :destroy

  has_one :trainer, dependent: :destroy

  def newsletter_subscriber
    NewsletterSubscriber.find_by(email: email.downcase.strip)
  end

  def newsletter_subscribed?
    newsletter_subscriber&.subscribed? || false
  end

end