class TrainersController < ApplicationController
  before_action :set_trainer, only: %i[ show edit update destroy update_profile update_courses ]
  before_action :authenticate_user!
  before_action :authorize_admin!, except: [ :update_profile ]
  # GET /trainers or /trainers.json
def index
    # .includes lädt die verknüpften Tabellen direkt mit, das macht die Seite extrem schnell!
    @trainers = Trainer.includes(:user, :courses).all
  end

  def show
    @courses_by_category = Course.order(:title).group_by { |c| c.title.split("(").first.strip }
  end

  # GET /trainers/new
  # ?q=...       → Suchergebnisse anzeigen
  # ?user_id=... → Bestätigungs-/Telefon-Formular anzeigen
  def new
    @trainer = Trainer.new

    if params[:user_id].present?
      @selected_user = User.find_by(id: params[:user_id])
      @trainer.user_id = @selected_user&.id
    elsif params[:q].present?
      already_trainer_ids = Trainer.pluck(:user_id)
      q = "%#{params[:q].strip}%"
      trainer_user_ids = Trainer.where(
        "first_name ILIKE ? OR last_name ILIKE ? OR CONCAT(first_name, ' ', last_name) ILIKE ?",
        q, q, q
      ).pluck(:user_id)
      @search_results = User.includes(:trainer)
                            .where("email ILIKE ? OR id IN (?)", q, trainer_user_ids + [ 0 ])
                            .where.not(id: already_trainer_ids)
                            .order(:email)
                            .limit(25)
    end
  end

  # GET /trainers/1/edit
  def edit
  end

  # POST /trainers or /trainers.json
  def create
    @trainer = Trainer.new(trainer_params)
    @trainer.user ||= current_user

    if @trainer.save
      if @trainer.user == current_user
        redirect_to my_profile_path, notice: "Profil wurde erstellt."
      else
        redirect_to trainers_path, notice: "#{@trainer.user.email} wurde als Trainer erfasst."
      end
    else
      if @trainer.user == current_user
        render "participants/my_profile", status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def invite
    email      = params[:email].to_s.strip.downcase
    first_name = params[:first_name].to_s.strip
    last_name  = params[:last_name].to_s.strip
    phone      = params[:phone].to_s.strip

    errors = []
    errors << "Vorname muss angegeben werden"    if first_name.blank?
    errors << "Nachname muss angegeben werden"   if last_name.blank?
    errors << "E-Mail ist ungültig"              unless email.match?(URI::MailTo::EMAIL_REGEXP)
    errors << "Telefonnummer muss angegeben werden" if phone.blank?
    errors << "Telefonnummer ist ungültig (mind. 7 Zeichen, erlaubt: +, Ziffern, Leerzeichen, -)" \
      if phone.present? && !phone.match?(/\A[\+\d][\d\s\-]{6,}\z/)

    unless errors.empty?
      @invite_errors = errors
      @invite_tab    = true
      @invite_first_name = first_name
      @invite_last_name  = last_name
      @invite_email      = email
      @invite_phone      = phone
      @trainer = Trainer.new
      return render :new, status: :unprocessable_entity
    end

    user = User.find_or_initialize_by(email: email)

    if user.persisted? && Trainer.exists?(user: user)
      @invite_errors     = ["#{email} ist bereits als Trainer erfasst."]
      @invite_tab        = true
      @invite_first_name = first_name
      @invite_last_name  = last_name
      @invite_email      = email
      @invite_phone      = phone
      @trainer = Trainer.new
      return render :new, status: :unprocessable_entity
    end

    raw_token, enc_token = Devise.token_generator.generate(User, :reset_password_token)

    if user.new_record?
      user.assign_attributes(
        password: SecureRandom.hex(16),
        confirmed_at: Time.current,
        reset_password_token: enc_token,
        reset_password_sent_at: Time.current
      )
      user.save!(validate: false)
    else
      user.update_columns(reset_password_token: enc_token, reset_password_sent_at: Time.current)
    end

    trainer = Trainer.create!(user: user, first_name: first_name, last_name: last_name, phone: phone)
    TrainerInvitationMailer.invite(trainer, raw_token).deliver_later

    redirect_to trainers_path,
      notice: "#{first_name} #{last_name} wurde eingeladen. Eine E-Mail mit dem Link zum Passwort setzen wurde verschickt."
  rescue => e
    Rails.logger.error "[TrainersController] invite Fehler: #{e.class}: #{e.message}"
    @invite_errors     = ["Es ist ein Fehler aufgetreten: #{e.message.truncate(120)}"]
    @invite_tab        = true
    @invite_first_name = params[:first_name]
    @invite_last_name  = params[:last_name]
    @invite_email      = params[:email]
    @invite_phone      = params[:phone]
    @trainer = Trainer.new
    render :new, status: :unprocessable_entity
  end

  def update
    if @trainer.update(trainer_params)
      redirect_to trainers_path, notice: "Trainer wurde aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @trainer.destroy!
    redirect_to trainers_path, notice: "Trainer wurde entfernt."
  end

  def update_courses
    course_ids = Array(params.dig(:trainer, :course_ids))
                   .reject(&:blank?)
                   .map(&:to_i)
    @trainer.course_ids = course_ids
    @trainer.save!(validate: false)
    redirect_to trainer_path(@trainer), notice: "Kurs-Zuweisung wurde gespeichert."
  rescue => e
    redirect_to trainer_path(@trainer), alert: "Fehler: #{e.message}"
  end

  def update_profile
    unless @trainer.user == current_user
      redirect_to root_path, alert: "Zugriff verweigert." and return
    end
    if @trainer.update(profile_params)
      redirect_to my_profile_path, notice: "Dein Profil wurde aktualisiert."
    else
      render "participants/my_profile", status: :unprocessable_entity
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_trainer
      @trainer = Trainer.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def trainer_params
      params.expect(trainer: [
        :user_id, :phone, :first_name, :last_name, :date_of_birth, :gender,
        :ahv_number, :street, :house_number, :zip_code, :city, :country,
        :nationality, :mother_tongue, :js_person_number, :iban, :js_anerkennung,
        course_ids: []
      ])
    end

    def profile_params
      params.require(:trainer).permit(
        :phone, :first_name, :last_name, :date_of_birth, :gender,
        :ahv_number, :street, :house_number, :zip_code, :city, :country,
        :nationality, :mother_tongue, :js_person_number, :iban, :js_anerkennung
      )
    end
end
