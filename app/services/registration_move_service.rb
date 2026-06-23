# Verschiebt eine CourseRegistration in einen anderen Kurs — bewusst auch
# kategorienübergreifend (z.B. KutuPlus → KutuPlus Jr.). Reine Admin-Funktion
# (siehe CourseRegistrationsController#move, mit authorize_admin! abgesichert).
#
# Kapselt die heiklen Nebenwirkungen eines Kurswechsels:
#   - Kapazität des Zielkurses (volle Kurse → Warteliste)
#   - training_session_id / trial_session_id zurücksetzen (gehören zum alten Kurs)
#   - Preis im Zielkurs neu ermitteln (Rabatte greifen kategorieabhängig)
#   - Warteliste des Quellkurses nachrücken lassen
# Eine Preisdifferenz wird NICHT automatisch erstattet/nachbelastet, sondern als
# Hinweis an den Admin zurückgegeben (price_diff_cents).
class RegistrationMoveService
  Result = Struct.new(:moved, :from_course, :to_course, :new_status,
                      :price_diff_cents, :reason, keyword_init: true)

  def self.call(registration, target_course, actor: nil)
    from_course = registration.course

    if target_course.nil? || target_course.id == from_course.id
      return Result.new(moved: false, reason: :same_course)
    end

    old_session_id  = registration.training_session_id
    old_price_cents = registration.paid_amount_cents.to_i

    target_course.with_lock do
      registration.reload
      registration.course = target_course
      pricing = DiscountCalculator.call(registration)

      registration.update!(
        course_id:           target_course.id,
        training_session_id: nil,
        trial_session_id:    nil,
        status:              capacity_status(target_course, registration),
        applied_price_cents: pricing[:price_cents],
        applied_discount:    pricing[:discount]
      )
    end

    # Auf dem Quellkurs ggf. den nächsten Wartelistenplatz nachrücken.
    WaitlistPromotionService.promote_next_from_waitlist(from_course, training_session_id: old_session_id)

    price_diff = registration.paid_amount_cents.to_i - old_price_cents

    Rails.logger.info(
      "[RegistrationMoveService] Registration #{registration.id} verschoben von " \
      "Kurs #{from_course.id} (#{from_course.title}) nach #{target_course.id} " \
      "(#{target_course.title}) durch #{actor&.email || 'unbekannt'}; " \
      "Status #{registration.status}, Preisdifferenz #{price_diff} Rappen"
    )

    Result.new(
      moved:            true,
      from_course:      from_course,
      to_course:        target_course,
      new_status:       registration.status,
      price_diff_cents: price_diff,
      reason:           nil
    )
  end

  # Nur aktive Vollanmeldungen werden im Zielkurs nach Kapazität neu eingestuft.
  # schnuppern/ausstehend/storniert behalten ihren Status.
  def self.capacity_status(course, registration)
    return registration.status unless registration.status.in?(%w[bestätigt warteliste])
    return "bestätigt" if course.max_participants.blank?

    confirmed = course.course_registrations
                      .where(status: %w[bestätigt schnuppern])
                      .where.not(id: registration.id)
                      .count
    confirmed >= course.max_participants ? "warteliste" : "bestätigt"
  end
  private_class_method :capacity_status
end
