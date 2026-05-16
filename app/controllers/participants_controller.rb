class ParticipantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_participant, only: %i[show edit update destroy]

  def index
    if current_user.admin? || Trainer.exists?(user: current_user)
      redirect_to my_profile_path and return
    end

    @participants = current_user.participants
      .includes(course_registrations: [ :course, :training_session ])

    all_regs = @participants.flat_map(&:course_registrations)

    # Nur aktive Semester-Kurse brauchen @upcoming_by_course (single_session-Kurse
    # haben ihre Session direkt auf der CourseRegistration via training_session_id;
    # abgeschlossene/stornierte Kurse brauchen keine upcoming sessions)
    today = Date.today
    semester_confirmed = all_regs.select { |r|
      r.status == "bestätigt" &&
      r.course.registration_mode != "single_session" &&
      (r.course.end_date.nil? || r.course.end_date >= today)
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

  def my_profile
    unless current_user.admin? || Trainer.exists?(user: current_user)
      redirect_to participants_path and return
    end
    @trainer = Trainer.find_or_create_by(user: current_user)
  end

  def show
  end

  def new
    if Trainer.exists?(user: current_user)
      redirect_to my_profile_path, alert: "Trainer können keine Teilnehmer erfassen." and return
    end
    @participant = Participant.new
    @participant.user_id = current_user.id unless current_user.admin?
  end

  def edit
  end

  def create
    if Trainer.exists?(user: current_user)
      redirect_to my_profile_path, alert: "Trainer können keine Teilnehmer erfassen." and return
    end
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
    allowed = [ :first_name, :last_name, :phone_number, :ahv_number, :date_of_birth, :gender,
                :street, :house_number, :zip_code, :city, :country, :nationality, :mother_tongue ]
    allowed += [ :js_person_number, :user_id ] if current_user.admin?
    params.expect(participant: allowed)
  end
end
