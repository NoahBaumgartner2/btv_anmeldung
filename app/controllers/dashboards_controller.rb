require "csv"

class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def admin
    authorize_admin!
    @courses = Course.includes(:course_registrations).order(start_date: :asc)

    @course_categories = @courses.map(&:category).compact_blank.uniq.sort
    @course_registration_modes = @courses.map(&:registration_mode).compact_blank.uniq

    course_q = params[:course_q].to_s.strip
    @courses = @courses.select { |c| c.title.to_s.downcase.include?(course_q.downcase) } if course_q.present?
    @courses = @courses.select { |c| c.category == params[:category] } if params[:category].present?
    @courses = @courses.select { |c| c.registration_mode == params[:registration_mode] } if params[:registration_mode].present?

    @export_profiles = ExportProfile.order(:name)

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

    @courses = Course.includes(
      { trainers: :user },
      training_sessions: :attendances,
      course_registrations: :participant
    ).order(start_date: :desc)

    # Globale Kennzahlen
    all_sessions = TrainingSession.all
    @total_sessions   = all_sessions.count
    @past_sessions    = all_sessions.where("start_time < ?", now).count
    @canceled_sessions = all_sessions.where(is_canceled: true).count

    non_canceled_attendances = Attendance.joins(:training_session).where(training_sessions: { is_canceled: false })
    @present_count  = non_canceled_attendances.where(status: "anwesend").count
    @absent_count   = non_canceled_attendances.where(status: "abwesend").count
    @excused_count  = non_canceled_attendances.where(status: "abgemeldet").count

    # Kurs-Filter (Multi-Select)
    @selected_course_ids = Array(params[:course_ids]).map(&:to_i).select(&:positive?)
  end

  def talents
    authorize_admin!
    @talented_registrations = CourseRegistration
      .joins(:course, :participant)
      .where(talent_flag: true)
      .where(courses: { allows_talent_marking: true })
      .includes(:course, :participant)
      .order("courses.title, participants.last_name, participants.first_name")
  end

  def open_attendances
    authorize_admin!

    @open_sessions = TrainingSession
      .where(is_canceled: false, attendance_confirmed_at: nil)
      .where.not(end_time: nil)
      .where("end_time < ?", Time.current)
      .includes(course: { course_trainers: { trainer: :user } })
      .order(:start_time)
  end

  def trainer
    authorize_trainer!
    @trainer = Trainer.find_by(user: current_user)
    @assigned_courses = @trainer ? @trainer.courses.order(start_date: :asc) : []

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
