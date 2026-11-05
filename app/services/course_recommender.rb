# Kursempfehlungen pro Kind für die Kursübersicht.
#
# Harte Filter (aus den Kursen, die die Familie ohnehin sieht): Alter passt
# (Course#accepts_participant_age? oder Altersausnahme – strenger als
# registration_blocked_by_age?, aber ohne Abfrage pro Kurs; empfohlen wird also nie
# ein Kurs, bei dem die Anmeldung am Alter scheitert), Kurs nicht voll, Kind nicht
# schon im Kurs und nicht schon aktiv in derselben Kategorie.
#
# Rangfolge pro Kategorie – Kurse werden jedes Semester neu angelegt, Kategorien
# bleiben, deshalb lernt der Algorithmus auf Kategorie-Ebene:
#   1. „Kinder mit denselben Kursen besuchen auch …“: Anteil der Kinder aus jeder
#      Kategorie des Kindes, die (gleichzeitig oder später) auch die Kandidaten-
#      Kategorie besucht haben. Erst ab MIN_SUPPORT gemeinsamen Kindern.
#   2. Weiterführung: das Kind war früher schon in der Kategorie.
#   3. Beliebt im gleichen Alter (±1 Jahr) – trägt Kinder ohne Kurshistorie.
#   4. Nähe: kleiner Bonus, der bis PROXIMITY_RANGE_KM auf null abfällt. Basis ist die
#      PLZ des Kindes, sonst die der Eltern. Ohne PLZ oder Kursort zählt sie nicht.
# Je Kategorie wird der nächstgelegene Kurs gezeigt (auf den Kilometer gerundet),
# danach entscheiden die freien Plätze.
class CourseRecommender
  Recommendation = Data.define(:course, :reason, :related_category, :score)

  PER_CHILD = 3
  MIN_SUPPORT = 2
  # Tatsächliche Teilnahme bzw. Interesse; ohne Abo-Einzelbuchungen.
  HISTORY_STATUSES = %w[bestätigt schnuppern].freeze
  ACTIVE_STATUSES = (CourseRegistration::OCCUPYING_STATUSES + %w[ausstehend warteliste]).freeze
  CONTINUE_WEIGHT = 0.5
  AGE_POPULARITY_WEIGHT = 0.2
  PROXIMITY_WEIGHT = 0.1
  PROXIMITY_RANGE_KM = 20.0

  def self.call(...) = new(...).call

  # participants: Kinder der Familie; courses: Kurse, die die Kursübersicht zeigt
  # (mit vorgeladenen course_registrations).
  def initialize(participants:, courses:)
    @children = participants.select(&:date_of_birth)
    @courses = courses
  end

  def call
    return {} if @children.empty? || @courses.empty?

    @children.to_h { |child| [ child, recommendations_for(child) ] }.reject { |_, recs| recs.empty? }
  end

  private

  def recommendations_for(child)
    history = categories_by_participant.fetch(child.id, Set.new)
    active = active_categories.fetch(child.id, Set.new)

    candidates = @courses.reject do |course|
      course.full? || registered_course_ids.include?([ child.id, course.id ]) ||
        active.include?(course.category_name) || !age_fits?(course, child)
    end

    home = SwissGeo.coordinates(child.zip_code.presence || child.user&.zip_code)

    candidates.group_by(&:category_name).filter_map do |category, courses|
      score, reason, related = score(child, category, history)
      course = courses.min_by { |c| [ distance_km(c, home)&.round || Float::INFINITY, -(c.spots_remaining || Float::INFINITY) ] }
      Recommendation.new(course: course, reason: reason, related_category: related, score: score + proximity_bonus(course, home))
    end.sort_by { |rec| [ -rec.score, -(rec.course.spots_remaining || Float::INFINITY), rec.course.title.to_s ] }
      .first(PER_CHILD)
  end

  def score(child, category, history)
    others_in_category = participants_by_category.fetch(category, Set.new) - [ child.id ]

    related, confidence = (history - [ category ]).filter_map { |own|
      others_in_own = participants_by_category.fetch(own, Set.new) - [ child.id ]
      common = (others_in_own & others_in_category).size
      [ own, common.to_f / others_in_own.size ] if common >= MIN_SUPPORT
    }.max_by(&:last)
    together = confidence.to_f

    continued = history.include?(category) ? CONTINUE_WEIGHT : 0.0
    peers = same_age_peers(child)
    popularity = peers.empty? ? 0.0 : (peers & others_in_category).size.to_f / peers.size * AGE_POPULARITY_WEIGHT

    reason = if together.positive? then :also_attended
    elsif continued.positive? then :continue
    elsif popularity.positive? then :age_popular
    else :age_fit
    end
    related = category if reason == :continue
    [ together + continued + popularity, reason, related ]
  end

  def distance_km(course, home)
    SwissGeo.distance_km(home, [ course.latitude, course.longitude ]) if home && course.latitude && course.longitude
  end

  def proximity_bonus(course, home)
    distance = distance_km(course, home)
    distance ? PROXIMITY_WEIGHT * [ 1 - distance / PROXIMITY_RANGE_KM, 0.0 ].max : 0.0
  end

  def age_fits?(course, child)
    course.accepts_participant_age?(child) || age_exemptions.include?([ child.id, course.id ])
  end

  def age_exemptions
    @age_exemptions ||= AgeExemption.where(participant_id: @children.map(&:id)).pluck(:participant_id, :course_id).to_set
  end

  def same_age_peers(child)
    age = child.age_at(Date.current)
    birth_dates.filter_map { |id, dob| id if id != child.id && (Participant.new(date_of_birth: dob).age_at(Date.current) - age).abs <= 1 }.to_set
  end

  # ── Daten (eine Abfrage für die ganze Anmeldegeschichte, 1 h gecacht) ────────

  def history_rows
    @history_rows ||= Rails.cache.fetch("course_recommender/history", expires_in: 1.hour) do
      CourseRegistration.joins(:course, :participant)
        .where(status: HISTORY_STATUSES, abo_source_registration_id: nil)
        .pluck(:participant_id, "courses.category", "courses.title", "participants.date_of_birth")
    end
  end

  def categories_by_participant
    @categories_by_participant ||= history_rows.each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |(pid, category, title, _), map|
      map[pid] << Course.category_name_for(category, title)
    end
  end

  def participants_by_category
    @participants_by_category ||= history_rows.each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |(pid, category, title, _), map|
      map[Course.category_name_for(category, title)] << pid
    end
  end

  def birth_dates
    @birth_dates ||= history_rows.filter_map { |pid, _, _, dob| [ pid, dob ] if dob }.uniq
  end

  def current_registrations
    @current_registrations ||= CourseRegistration.joins(:course).merge(Course.not_archived)
      .where(participant_id: @children.map(&:id), status: ACTIVE_STATUSES)
      .pluck(:participant_id, :course_id, "courses.category", "courses.title")
  end

  def registered_course_ids
    @registered_course_ids ||= current_registrations.to_set { |pid, course_id, _, _| [ pid, course_id ] }
  end

  def active_categories
    @active_categories ||= current_registrations.each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |(pid, _, category, title), map|
      map[pid] << Course.category_name_for(category, title)
    end
  end
end
