class ClubSetting < ApplicationRecord
  has_one_attached :logo

  normalizes :contact_phone, with: PhoneNumberFormatter

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

  # Lesbare Schriftfarbe auf einer Vereinsfarbe: dunkel auf hellen Farben
  # (z.B. Gelb), weiss auf dunklen (z.B. Rot). WCAG-Luminanz, Schwelle so
  # gewählt, dass der Kontrast der gewählten Farbe der grössere ist.
  def text_color_on(hex)
    r, g, b = hex.delete("#").scan(/../).map { |c| c.to_i(16) / 255.0 }
      .map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
    luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
    luminance > 0.179 ? "#0b1220" : "#ffffff"
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
