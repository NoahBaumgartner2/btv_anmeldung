class TrainersController < ApplicationController
  before_action :set_trainer, only: %i[ show edit update destroy ]
  before_action :authenticate_user!
  before_action :authorize_admin!
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
      @search_results = User.where("email ILIKE ?", "%#{params[:q]}%")
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
    if @trainer.save
      redirect_to trainers_path, notice: "#{@trainer.user.email} wurde als Trainer erfasst."
    else
      render :new, status: :unprocessable_entity
    end
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_trainer
      @trainer = Trainer.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def trainer_params
      params.expect(trainer: [ :user_id, :phone, course_ids: [] ])
    end
end
