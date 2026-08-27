# Ermittelt den zu zahlenden Preis für eine Registration unter Berücksichtigung
# der pro Kurs konfigurierten Preisreduktionen (Jugendpreis / Geschwister / Zweitkurs).
# Treffen mehrere Rabatte zu, gewinnt der günstigere Preis (kein Stacking).
# Rückgabe: { price_cents:, discount: nil | "youth" | "sibling" | "second_course" }
class DiscountCalculator
  def self.call(registration)
    course = registration.course
    full_price = { price_cents: course.price_cents.to_i, discount: nil }

    candidates = []

    # Jugendpreis: rein altersbasiert, unabhängig von discounts_enabled
    if course.youth_price_cents.present? && youth_eligible?(registration)
      candidates << { price_cents: course.youth_price_cents, discount: "youth" }
    end

    # Geschwister-/Zweitkurs-Rabatte nur bei aktivierten Rabatten + gesetzter Kategorie
    if course.discounts_enabled? && course.category.present?
      if course.sibling_price_cents.present? && sibling_registration_exists?(registration)
        candidates << { price_cents: course.sibling_price_cents, discount: "sibling" }
      end
      if course.second_course_price_cents.present? && second_course_registration_exists?(registration)
        candidates << { price_cents: course.second_course_price_cents, discount: "second_course" }
      end
    end

    # Späteres Anmelden: wer erst einsteigt, nachdem der Kurs schon läuft, zahlt
    # nicht den vollen Preis für bereits verpasste Trainings. Berechnung via
    # Course#late_registration_deduction_cents (auch von courses#index für die
    # Preisanzeige vor der eigentlichen Anmeldung genutzt). Das darin eingebaute
    # eine "gratis" Training deckt bei einer Schnupper-Umwandlung genau das
    # bereits stattgefundene Schnuppertraining ab - kein separater Rabatt nötig.
    #
    # "at": Für frische Anmeldungen ist created_at ~ jetzt. Eine Schnupper-Anmeldung
    # kann dagegen tagelang mit demselben created_at bestehen bleiben, bis sie nach
    # dem Schnuppertraining in eine reguläre Anmeldung umgewandelt wird - dort muss
    # ab dem Umwandlungszeitpunkt (jetzt) gerechnet werden, nicht ab der alten
    # Schnupper-Erstellung.
    at = registration.trial? ? Time.current : registration.created_at
    deduction = course.late_registration_deduction_cents(at: at)
    if deduction.positive?
      candidates << { price_cents: [ full_price[:price_cents] - deduction, 0 ].max, discount: "late_registration" }
    end

    candidates.min_by { |c| c[:price_cents] } || full_price
  end

  # Jugendpreis greift, wenn das Alter zum Kursstart <= youth_max_age ist.
  def self.youth_eligible?(registration)
    participant = registration.participant
    return false unless participant&.date_of_birth
    max_age = registration.course.youth_max_age || 20
    age = participant.age_at(registration.course.age_reference_date)
    age.present? && age <= max_age
  end
  private_class_method :youth_eligible?

  # Bestehende Anmeldungen derselben Kategorie zählen nur, wenn sie bestätigt
  # oder bezahlt sind — zwei gleichzeitig ausstehende Anmeldungen rabattieren
  # sich nicht gegenseitig. Stornierte zählen nie (auch wenn bezahlt).
  #
  # Nur früher erstellte Anmeldungen zählen (created_at, id als Tiebreaker):
  # sonst würden sich zwei Geschwister, die im selben Kurs angemeldet sind,
  # gegenseitig als "bestehende Anmeldung" sehen und beide den Rabatt bekommen,
  # statt nur die zeitlich spätere. So zahlt immer die zuerst angemeldete
  # Person den vollen Preis, jede weitere den Rabatt.
  def self.existing_registrations(registration)
    CourseRegistration
      .joins(:course)
      .where(courses: { category: registration.course.category })
      .where.not(id: registration.id)
      .where.not(status: "storniert")
      .where("course_registrations.status = ? OR course_registrations.payment_cleared = ?", "bestätigt", true)
      .where(
        "course_registrations.created_at < ? OR (course_registrations.created_at = ? AND course_registrations.id < ?)",
        registration.created_at, registration.created_at, registration.id
      )
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
