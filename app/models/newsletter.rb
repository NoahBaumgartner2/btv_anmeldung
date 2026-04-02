class Newsletter < ApplicationRecord
  STATUSES = %w[draft sent].freeze

  validates :title,   presence: true
  validates :subject, presence: true
  validates :status,  inclusion: { in: STATUSES }

  before_validation { self.status ||= "draft" }

  scope :drafts, -> { where(status: "draft") }
  scope :sent,   -> { where(status: "sent") }

  def draft? = status == "draft"
  def sent?  = status == "sent"
end
