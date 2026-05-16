class ClubSetting < ApplicationRecord
  has_one_attached :logo

  validates :primary_color,   format: { with: /\A#[0-9A-Fa-f]{6}\z/, allow_blank: true }
  validates :secondary_color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, allow_blank: true }

  # ── Single-row accessor ─────────────────────────────────────────────────────
  def self.current
    first_or_initialize
  end

  # ── Effective values with fallbacks ────────────────────────────────────────
  # Gibt nur streng validierte Hex-Farben zurück – auch wenn der DB-Wert
  # manipuliert wurde, kommt niemals unsanitisierter CSS-Inhalt heraus.
  def effective_primary_color
    safe_hex_color(primary_color) || "#dc2626"
  end

  def effective_secondary_color
    safe_hex_color(secondary_color) || "#1d4ed8"
  end

  before_save :normalize_contact_website

  private

  def normalize_contact_website
    return if contact_website.blank?
    unless contact_website.match?(/\Ahttps?:\/\//i)
      self.contact_website = "https://#{contact_website}"
    end
  end

  # Gibt den Wert nur zurück wenn er exakt dem Format #RRGGBB entspricht.
  # Verhindert CSS-Injection auch bei direkt manipulierten DB-Werten.
  def safe_hex_color(value)
    value if value.present? && value.match?(/\A#[0-9A-Fa-f]{6}\z/)
  end

  public

  def logo_url
    return nil unless logo.attached?

    Rails.application.routes.url_helpers.rails_storage_proxy_path(logo, only_path: true)
  end
end
