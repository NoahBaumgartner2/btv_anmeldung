require "csv"

class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def admin
    authorize_admin!
    # Nur laufende Kurse; beendete/deaktivierte stehen auf der Archiv-Seite.
    @courses = Course.not_archived.includes(:course_registrations, :term).order(start_date: :asc).to_a
    @archived_count = Course.archived.count

    @course_categories = @courses.map(&:category).compact_blank.uniq.sort
    @course_registration_modes = @courses.map(&:registration_mode).compact_blank.uniq

    course_q = params[:course_q].to_s.strip
    @courses = @courses.select { |c| c.title.to_s.downcase.include?(course_q.downcase) } if course_q.present?
    @courses = @courses.select { |c| c.category == params[:category] } if params[:category].present?
    @courses = @courses.select { |c| c.registration_mode == params[:registration_mode] } if params[:registration_mode].present?

    @course_limit = [ params[:course_limit].to_i, 10 ].max
    @courses_total_count = @courses.size
    @courses = @courses.first(@course_limit)

    @export_profiles = ExportProfile.order(:name)
    @nav_badges = {
      export_profiles: @export_profiles.size,
      newsletters: Newsletter.drafts.count,
      newsletter_subscribers: NewsletterSubscriber.subscribed.count
    }

    # Handlungsbedarf: nur Kacheln mit Wert > 0 werden angezeigt.
    @action_items = [
      { key: :open_attendances, count: TrainingSession.attendance_open.count, path: open_attendances_dashboard_path, tone: :red },
      { key: :open_charges, count: SupplementaryCharge.where(status: "offen").count, path: admin_supplementary_charges_path, tone: :amber },
      { key: :open_payments, count: CourseRegistration.payment_open.count, path: open_payments_dashboard_path, tone: :indigo },
      { key: :newsletter_drafts, count: @nav_badges[:newsletters], path: newsletters_path, tone: :gray }
    ].select { |item| item[:count].positive? }

    q = params[:q].to_s.strip
    if q.length >= 2
      pattern = "%#{q}%"
      @participants = Participant.includes(:user)
                                 .joins(:user)
                                 .where(
                                   "participants.first_name ILIKE :p OR participants.last_name ILIKE :p OR users.email ILIKE :p OR CONCAT(participants.first_name, ' ', participants.last_name) ILIKE :p",
                                   p: pattern
                                 )
                                 .order(last_name: :asc, first_name: :asc)
                                 .limit(50)
    else
      @participants = Participant.none
    end
  end

  # Archiv: beendete und deaktivierte Kurse mit Suche und Filtern, nach Zeitraum
  # gruppiert (neuester zuerst), je 30 Kurse pro Stufe.
  def archive
    authorize_admin!
    scope = Course.archived.left_joins(:term).includes(:term, :course_registrations)

    @q = params[:q].to_s.strip
    scope = scope.where("courses.title ILIKE ?", "%#{Course.sanitize_sql_like(@q)}%") if @q.present?
    case params[:term_id]
    when "none" then scope = scope.where(term_id: nil)
    when /\A\d+\z/ then scope = scope.where(term_id: params[:term_id])
    end
    scope = scope.where(category: params[:category]) if params[:category].present?
    scope = scope.where.not(deactivated_at: nil) if params[:status] == "deactivated"
    scope = scope.where(deactivated_at: nil) if params[:status] == "ended"

    direction = params[:sort] == "oldest" ? "ASC" : "DESC"
    scope = scope.order(Arel.sql("terms.start_date #{direction} NULLS LAST, courses.end_date #{direction} NULLS LAST, courses.id #{direction}"))

    @filtered = %i[q term_id category status].any? { |key| params[key].present? }
    @terms = Term.order(start_date: :desc)
    @categories = Course.archived.where.not(category: [ nil, "" ]).distinct.order(:category).pluck(:category)
    @courses, @courses_more = load_more(scope, per: 30)
  end

  def export_participants
    authorize_admin!
    profile = ExportProfile.find(params[:profile_id])

    q = params[:q].to_s.strip
    scope = Participant.includes(:user, :courses).joins(:user)

    if q.length >= 2
      pattern = "%#{q}%"
      scope = scope.where(
        "participants.first_name ILIKE :p OR participants.last_name ILIKE :p OR users.email ILIKE :p OR CONCAT(participants.first_name, ' ', participants.last_name) ILIKE :p",
        p: pattern
      )
    end

    if profile.course_id?
      scope = scope.joins(:course_registrations)
                   .where(course_registrations: { course_id: profile.course_id })
    end

    participants = scope.order(last_name: :asc, first_name: :asc)

    csv_data = profile.generate_csv(participants)
    filename  = "#{profile.name.parameterize}-#{Date.today}.csv"
    send_data "\xEF\xBB\xBF#{csv_data}", filename: filename, type: "text/csv; charset=utf-8", disposition: "attachment"
  end

  def stats
    authorize_admin!

    now = Time.current

    # Kursfilter: alle Titel (leicht). Kurs-Karten: nur ausgewählte bzw. die
    # neuesten, je 10 pro Stufe – sonst lädt die Seite mit den Jahren alle
    # Trainings und Anwesenheiten aller Kurse.
    @filter_courses = Course.order(start_date: :desc).select(:id, :title)
    @selected_course_ids = Array(params[:course_ids]).map(&:to_i).select(&:positive?)
    cards = Course.includes(
      { trainers: :user },
      training_sessions: :attendances,
      course_registrations: :participant
    ).order(start_date: :desc)
    cards = cards.where(id: @selected_course_ids) if @selected_course_ids.any?
    @courses, @courses_more = load_more(cards, per: 10, param: :course_page)

    # Globale Kennzahlen
    all_sessions = TrainingSession.all
    @total_sessions   = all_sessions.count
    @past_sessions    = all_sessions.where("start_time < ?", now).count
    @canceled_sessions = all_sessions.where(is_canceled: true).count

    non_canceled_attendances = Attendance.joins(:training_session).where(training_sessions: { is_canceled: false })
    @present_count  = non_canceled_attendances.where(status: "anwesend").count
    @absent_count   = non_canceled_attendances.where(status: "abwesend").count
    @excused_count  = non_canceled_attendances.where(status: "abgemeldet").count
  end

  def talents
    authorize_admin!
    @talented_registrations, @talents_more = load_more(CourseRegistration
      .joins(:course, :participant)
      .where(talent_flag: true)
      .where(courses: { allows_talent_marking: true })
      .includes(:course, :participant)
      .order("courses.title, participants.last_name, participants.first_name"), per: 50)
  end

  def open_attendances
    authorize_admin!

    @open_sessions, @open_sessions_more = load_more(TrainingSession.attendance_open
      .includes(course: { course_trainers: { trainer: :user } })
      .order(:start_time), per: 50)
  end

  def open_payments
    authorize_admin!
    @open_registrations, @open_registrations_more = load_more(CourseRegistration.payment_open
      .includes(:course, participant: :user)
      .order("courses.title", :created_at), per: 50)
  end

  def trainer
    authorize_trainer!
    @trainer = Trainer.find_by(user: current_user)
    @assigned_courses = @trainer ? @trainer.courses.where(deactivated_at: nil).order(start_date: :asc) : []

    now = Time.current
    all_sessions = TrainingSession.where(course: @assigned_courses)
                                  .where("start_time >= ?", now.beginning_of_day)
                                  .order(:start_time)

    @todays_sessions  = all_sessions.select { |s| s.start_time.to_date == now.to_date }
    @next_session     = all_sessions.find   { |s| s.start_time > now }

    # nächste Session pro Kurs (für die Kurs-Karten)
    @next_session_per_course = {}
    all_sessions.each do |s|
      @next_session_per_course[s.course_id] ||= s
    end

    # Trainings, für die ICH als Ersatztrainer:in eingetragen wurde (unabhängig
    # davon, ob ich sonst dem Kurs zugewiesen bin) – für Sichtbarkeit im Dashboard.
    @substitute_sessions = @trainer ? TrainingSession.where(substitute_trainer: @trainer)
                                                      .where("start_time >= ?", now.beginning_of_day)
                                                      .order(:start_time)
                                                      .to_a : []
  end
end
