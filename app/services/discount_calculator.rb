# Ermittelt den zu zahlenden Preis für eine Registration unter Berücksichtigung
# der pro Kurs konfigurierten Preisreduktionen (Geschwister / Zweitkurs).
# Treffen beide Rabatte zu, gewinnt der günstigere Preis (kein Stacking).
# Rückgabe: { price_cents:, discount: nil | "sibling" | "second_course" }
class DiscountCalculator
  def self.call(registration)
    course = registration.course
    full_price = { price_cents: course.price_cents.to_i, discount: nil }
    return full_price unless course.discounts_enabled? && course.category.present?

    candidates = []

    if course.sibling_price_cents.present? && sibling_registration_exists?(registration)
      candidates << { price_cents: course.sibling_price_cents, discount: "sibling" }
    end

    if course.second_course_price_cents.present? && second_course_registration_exists?(registration)
      candidates << { price_cents: course.second_course_price_cents, discount: "second_course" }
    end

    candidates.min_by { |c| c[:price_cents] } || full_price
  end

  # Bestehende Anmeldungen derselben Kategorie zählen nur, wenn sie bestätigt
  # oder bezahlt sind — zwei gleichzeitig ausstehende Anmeldungen rabattieren
  # sich nicht gegenseitig. Stornierte zählen nie (auch wenn bezahlt).
  def self.existing_registrations(registration)
    CourseRegistration
      .joins(:course)
      .where(courses: { category: registration.course.category })
      .where.not(id: registration.id)
      .where.not(status: "storniert")
      .where("course_registrations.status = ? OR course_registrations.payment_cleared = ?", "bestätigt", true)
  end
  private_class_method :existing_registrations

  # Anderes Kind desselben Elternkontos in einem Kurs derselben Kategorie.
  def self.sibling_registration_exists?(registration)
    participant = registration.participant
    return false if participant.user_id.blank?

    existing_registrations(registration)
      .joins(:participant)
      .where(participants: { user_id: participant.user_id })
      .where.not(participant_id: participant.id)
      .exists?
  end
  private_class_method :sibling_registration_exists?

  # Dieselbe Person (kontoübergreifend via Identitäts-Match) in einem
  # anderen Kurs derselben Kategorie.
  def self.second_course_registration_exists?(registration)
    existing_registrations(registration)
      .where(participant_id: registration.participant.identity_sibling_ids)
      .where.not(course_id: registration.course_id)
      .exists?
  end
  private_class_method :second_course_registration_exists?
end
