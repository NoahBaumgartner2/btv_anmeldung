module MailerHelper
  EMAIL_LOGO_MAX_HEIGHT = 56
  EMAIL_LOGO_MAX_WIDTH  = 200

  # Gibt { url:, width:, height: } zurück oder nil, wenn kein
  # E-Mail-taugliches Logo vorhanden ist (kein Logo oder SVG).
  def email_logo(club)
    logo = club&.logo
    return nil unless logo&.attached?
    return nil if logo.content_type == "image/svg+xml"

    logo.analyze if !logo.analyzed? || logo.metadata[:width].blank? || logo.metadata[:height].blank?
    natural_w = logo.metadata[:width]
    natural_h = logo.metadata[:height]

    if natural_w.present? && natural_h.present? && natural_h.positive?
      height = EMAIL_LOGO_MAX_HEIGHT
      width  = (natural_w * height / natural_h.to_f).round
      if width > EMAIL_LOGO_MAX_WIDTH
        width  = EMAIL_LOGO_MAX_WIDTH
        height = (natural_h * width / natural_w.to_f).round
      end
    else
      # Masse unbekannt: nur Höhe setzen, Breite überlässt das E-Mail-Programm
      # dem natürlichen Seitenverhältnis (gedeckelt durch max-width:200px im Template).
      width  = nil
      height = EMAIL_LOGO_MAX_HEIGHT
    end

    # 2x-Variant für Retina-Displays (resize_to_limit erhält das Seitenverhältnis)
    limit_w = (width || EMAIL_LOGO_MAX_WIDTH) * 2
    limit_h = height * 2
    variant = logo.variant(resize_to_limit: [ limit_w, limit_h ]).processed
    { url: rails_representation_url(variant), width: width, height: height }
  rescue ActiveStorage::Error, LoadError, StandardError => e
    Rails.logger.warn "[MailerHelper] email_logo Fehler: #{e.class}: #{e.message}"
    # Fallback: Original-URL mit fixen Dimensionen, damit die Mail nie crasht
    { url: rails_blob_url(logo), width: nil, height: EMAIL_LOGO_MAX_HEIGHT }
  end
end
