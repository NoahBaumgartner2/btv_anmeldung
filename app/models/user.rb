class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Ein User (Elternteil) kann mehrere Teilnehmer (Kinder) verwalten:
  has_many :participants, dependent: :destroy

  has_one :trainer, dependent: :destroy
end