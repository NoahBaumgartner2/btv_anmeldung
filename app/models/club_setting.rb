class ClubSetting < ApplicationRecord
  has_one_attached :logo

  validates :primary_color,   format: { with: /\A#[0-9A-Fa-f]{6}\z/, allow_blank: true }
  validates :secondary_color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, allow_blank: true }

  # ── Single-row accessor ─────────────────────────────────────────────────────
  def self.current
    first_or_initialize
  end

  # ── Effective values with fallbacks ────────────────────────────────────────
  def effective_primary_color
    primary_color.presence || "#dc2626"
  end

  def effective_secondary_color
    secondary_color.presence || "#1d4ed8"
  end

  def logo_url
    return nil unless logo.attached?

    Rails.application.routes.url_helpers.rails_blob_path(logo, only_path: true)
  end
end
