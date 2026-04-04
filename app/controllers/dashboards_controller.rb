class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def admin
    authorize_admin!
    @courses = Course.includes(:course_registrations).order(start_date: :asc)

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

  def stats
    authorize_admin!

    now = Time.current

    @courses = Course.includes(
      training_sessions: :attendances,
      course_registrations: :participant
    ).order(start_date: :desc)

    # Globale Kennzahlen
    all_sessions = TrainingSession.all
    @total_sessions   = all_sessions.count
    @past_sessions    = all_sessions.where("start_time < ?", now).count
    @canceled_sessions = all_sessions.where(is_canceled: true).count

    all_attendances = Attendance.all
    @present_count  = all_attendances.where(status: "anwesend").count
    @absent_count   = all_attendances.where(status: "abwesend").count
    @excused_count  = all_attendances.where(status: "abgemeldet").count

    # Kurs-Filter
    @selected_course_id = params[:course_id].presence&.to_i
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
  end
end