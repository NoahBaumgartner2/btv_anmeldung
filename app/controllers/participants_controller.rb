class ParticipantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_participant, only: %i[show edit update destroy]

  def index
    @participants = current_user.participants
      .includes(course_registrations: [ :course, :training_session ])

    all_regs = @participants.flat_map(&:course_registrations)

    # Nur Semester-Kurse brauchen @upcoming_by_course (single_session-Kurse haben
    # ihre Session direkt auf der CourseRegistration via training_session_id)
    semester_confirmed = all_regs.select { |r|
      r.status == "bestätigt" && r.course.registration_mode != "single_session"
    }
    semester_course_ids = semester_confirmed.map(&:course_id).uniq
    semester_reg_ids    = semester_confirmed.map(&:id)

    upcoming = TrainingSession
      .where(course_id: semester_course_ids, is_canceled: false)
      .where("start_time > ?", Time.current)
      .order(:start_time)

    @upcoming_by_course = upcoming.each_with_object(Hash.new { |h, k| h[k] = [] }) do |session, hash|
      hash[session.course_id] << session if hash[session.course_id].size < 3
    end

    @unsubscribed_pairs = Attendance
      .where(course_registration_id: semester_reg_ids, status: "abgemeldet")
      .pluck(:course_registration_id, :training_session_id)
      .to_set
  end

  def show
  end

  def new
    @participant = Participant.new
    @participant.user_id = current_user.id unless current_user.admin?
  end

  def edit
  end

  def create
    @participant = Participant.new(participant_params)
    @participant.user_id = current_user.id unless current_user.admin?

    if @participant.save
      redirect_to participants_path, notice: "#{@participant.first_name} #{@participant.last_name} wurde erfolgreich erfasst."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @participant.update(participant_params)
      redirect_to participants_path, notice: "#{@participant.first_name} wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @participant.destroy!
    redirect_to participants_path, notice: "Person wurde entfernt."
  end

  private

  def set_participant
    @participant = Participant.find(params.expect(:id))
    unless current_user.admin? || @participant.user_id == current_user.id
      redirect_to root_path, alert: "Zugriff verweigert." and return
    end
  end

  def participant_params
    allowed = [ :first_name, :last_name, :phone_number, :ahv_number, :date_of_birth, :gender ]
    allowed << :user_id if current_user.admin?
    params.expect(participant: allowed)
  end
end
