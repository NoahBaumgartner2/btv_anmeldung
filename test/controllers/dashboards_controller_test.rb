require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "Trainer-Dashboard zählt nur echte Wartelisten-Einträge (nicht storniert/schnuppern/ausstehend)" do
    trainer_user = User.create!(
      email: "dash-trainer@example.com", password: "password123",
      confirmed_at: Time.current, privacy_accepted: true
    )
    trainer = Trainer.create!(
      user: trainer_user, first_name: "Test", last_name: "Trainer",
      phone: "+41 79 111 22 33", date_of_birth: Date.new(1990, 1, 1), gender: "weiblich",
      ahv_number: "756.9999.8888.77", street: "Weg", house_number: "1",
      zip_code: "3000", city: "Bern", country: "CH", nationality: "CH", mother_tongue: "DE"
    )

    course = Course.new(
      title: "Dashboard-Kurs", registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false,
      max_participants: 14, enable_waitlist: true
    )
    course.save!(validate: false)
    CourseTrainer.create!(course: course, trainer: trainer)

    build = ->(name, status) do
      p = Participant.new(
        user: users(:two), first_name: name, last_name: "Test",
        date_of_birth: Date.new(2015, 1, 1)
      )
      p.save!(validate: false)
      CourseRegistration.new(course: course, participant: p, status: status, payment_cleared: false)
                        .save!(validate: false)
    end

    2.times { |i| build.call("Best#{i}", "bestätigt") }
    3.times { |i| build.call("Wait#{i}", "warteliste") }   # echte Warteliste = 3
    2.times { |i| build.call("Storno#{i}", "storniert") }
    build.call("Schnupper", "schnuppern")

    sign_in trainer_user
    get dashboards_trainer_path

    assert_response :success
    # Die orange Wartelisten-Kennzahl ist eindeutig (nur 1x im Trainer-Dashboard).
    # Vor dem Fix wurde where.not("bestätigt") = 6 gezählt; korrekt sind 3.
    assert_select "p.text-orange-500", { text: "3" },
      "Wartelisten-Kennzahl muss nur echte 'warteliste'-Einträge zählen"
  end

  # ── Kommandozentrale: Kurs-Suche/Filter ──────────────────────────────────────

  def make_dashboard_course(title:, category:, registration_mode:)
    course = Course.new(title: title, category: category, registration_type: registration_mode,
      registration_mode: registration_mode, has_payment: false, has_ticketing: false,
      allows_holiday_deduction: false)
    course.save!(validate: false)
    course
  end

  test "Kommandozentrale zeigt ohne Filter alle Kurse" do
    make_dashboard_course(title: "Turnen A", category: "Turnen", registration_mode: "semester")
    make_dashboard_course(title: "Pilates B", category: "Pilates", registration_mode: "quartal")

    sign_in users(:admin)
    get dashboards_admin_path

    assert_response :success
    assert_match "Turnen A", response.body
    assert_match "Pilates B", response.body
  end

  test "Kommandozentrale filtert Kurse nach Suchbegriff" do
    make_dashboard_course(title: "Turnen A", category: "Turnen", registration_mode: "semester")
    make_dashboard_course(title: "Pilates B", category: "Pilates", registration_mode: "quartal")

    sign_in users(:admin)
    get dashboards_admin_path, params: { course_q: "Turnen" }

    assert_response :success
    assert_match "Turnen A", response.body
    assert_no_match "Pilates B", response.body
  end

  test "Kommandozentrale filtert Kurse nach Kategorie" do
    make_dashboard_course(title: "Turnen A", category: "Turnen", registration_mode: "semester")
    make_dashboard_course(title: "Pilates B", category: "Pilates", registration_mode: "quartal")

    sign_in users(:admin)
    get dashboards_admin_path, params: { category: "Pilates" }

    assert_response :success
    assert_match "Pilates B", response.body
    assert_no_match "Turnen A", response.body
  end

  test "Kommandozentrale filtert Kurse nach Semester/Quartal" do
    make_dashboard_course(title: "Turnen A", category: "Turnen", registration_mode: "semester")
    make_dashboard_course(title: "Pilates B", category: "Pilates", registration_mode: "quartal")

    sign_in users(:admin)
    get dashboards_admin_path, params: { registration_mode: "quartal" }

    assert_response :success
    assert_match "Pilates B", response.body
    assert_no_match "Turnen A", response.body
  end
end
