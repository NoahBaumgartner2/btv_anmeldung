class ParticipantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_participant, only: %i[show edit update destroy]

  def index
    @participants = current_user.participants.includes(course_registrations: :course)

    confirmed_registrations = @participants.flat_map(&:course_registrations).select { |r| r.status == "bestätigt" }
    confirmed_course_ids = confirmed_registrations.map(&:course_id).uniq
    confirmed_reg_ids = confirmed_registrations.map(&:id)

    upcoming = TrainingSession
      .where(course_id: confirmed_course_ids, is_canceled: false)
      .where("start_time > ?", Time.current)
      .order(:start_time)
      .includes(:attendances)

    @upcoming_by_course = upcoming.each_with_object(Hash.new { |h, k| h[k] = [] }) do |session, hash|
      hash[session.course_id] << session if hash[session.course_id].size < 3
    end

    @unsubscribed_pairs = Attendance
      .where(course_registration_id: confirmed_reg_ids, status: "abgemeldet")
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
