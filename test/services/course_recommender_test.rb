require "test_helper"

class CourseRecommenderTest < ActiveSupport::TestCase
  setup do
    @parent = users(:parent_only)
    @child = kid("Lena", 8)
  end

  def kid(name, age)
    Participant.new(user: @parent, first_name: name, last_name: "Test", date_of_birth: (age.years + 2.months).ago.to_date)
      .tap { |p| p.save!(validate: false) }
  end

  def course(title, category:, ended: false, **attrs)
    Course.new(title: title, category: category, registration_type: "semester", registration_mode: "semester",
               has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
               end_date: ended ? 1.month.ago : 3.months.from_now, **attrs).tap { |c| c.save!(validate: false) }
  end

  def register(participant, course, status: "bestätigt")
    CourseRegistration.new(course: course, participant: participant, status: status,
                           payment_cleared: true, holiday_deduction_claimed: false).save!(validate: false)
  end

  def recommend(courses, children: [ @child ])
    CourseRecommender.call(participants: children, courses: Course.where(id: courses.map(&:id)).includes(:course_registrations).to_a)
  end

  test "empfiehlt, was Kinder mit derselben Kurshistorie besuchen, und nennt den Grund" do
    old_turnen = course("Kunstturnen HS", category: "Kunstturnen", ended: true)
    old_pilates = course("Pilates HS", category: "Pilates", ended: true)
    old_krabbel = course("Krabbelgym HS", category: "Krabbelgym", ended: true)
    3.times { |i| k = kid("Peer#{i}", 8); register(k, old_turnen); register(k, old_pilates) }
    register(kid("Andere", 8), old_krabbel)
    register(@child, old_turnen)

    pilates = course("Pilates FS", category: "Pilates")
    krabbel = course("Krabbelgym FS", category: "Krabbelgym")
    turnen = course("Kunstturnen FS", category: "Kunstturnen")

    recs = recommend([ pilates, krabbel, turnen ])[@child]
    assert_equal [ pilates, turnen, krabbel ], recs.map(&:course)
    assert_equal :also_attended, recs.first.reason
    assert_equal "Kunstturnen", recs.first.related_category
    assert_equal :continue, recs.second.reason
    assert_equal "Kunstturnen", recs.second.related_category
  end

  test "ein einzelnes gemeinsames Kind ist noch kein Muster" do
    old_turnen = course("Kunstturnen HS", category: "Kunstturnen", ended: true)
    old_pilates = course("Pilates HS", category: "Pilates", ended: true)
    k = kid("Einzeln", 8)
    register(k, old_turnen)
    register(k, old_pilates)
    register(@child, old_turnen)

    rec = recommend([ course("Pilates FS", category: "Pilates") ])[@child].first
    assert_not_equal :also_attended, rec.reason
  end

  test "filtert falsches Alter, volle Kurse, bestehende Anmeldungen und aktive Kategorien" do
    too_young_for = course("Krabbel 1–3", category: "Krabbelgym", max_age: 3)
    full = course("Voll", category: "Volleyball", max_participants: 1)
    register(kid("Platzhalter", 8), full)
    mine = course("Schon dabei", category: "Tanz")
    register(@child, mine)
    same_category = course("Tanz am Freitag", category: "Tanz")
    free = course("Frei", category: "Parkour")

    recs = recommend([ too_young_for, full, mine, same_category, free ])[@child]
    assert_equal [ free ], recs.map(&:course)
  end

  test "höchstens 3 Empfehlungen pro Kind, eine pro Kategorie" do
    courses = %w[A B C D].flat_map { |cat| [ course("#{cat} Mo", category: cat), course("#{cat} Di", category: cat) ] }
    recs = recommend(courses)[@child]
    assert_equal 3, recs.size
    assert_equal recs.map { |r| r.course.category }.uniq.size, recs.size
  end

  test "Kind ohne Geburtsdatum oder ohne passende Kurse erscheint nicht" do
    no_dob = Participant.new(user: @parent, first_name: "Ohne", last_name: "Datum").tap { |p| p.save!(validate: false) }
    result = recommend([ course("Nur Kleinkinder", category: "Krabbelgym", max_age: 2) ], children: [ @child, no_dob ])
    assert_empty result
  end
end
