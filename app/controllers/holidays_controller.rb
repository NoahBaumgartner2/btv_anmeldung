class HolidaysController < ApplicationController
  before_action :set_holiday, only: %i[ show edit update destroy ]
  before_action :authorize_admin!

  # GET /holidays or /holidays.json
  def index
    @holidays = Holiday.order(start_date: :asc)
  end

  # GET /holidays/1 or /holidays/1.json
  def show
  end

  # GET /holidays/new
  def new
    @holiday = Holiday.new
  end

  # GET /holidays/1/edit
  def edit
  end

  # POST /holidays or /holidays.json
  def create
    @holiday = Holiday.new(holiday_params)
    if @holiday.save
      # Wir leiten einfach "back" (zurück), da du meistens vom Kurs-Dashboard kommst
      redirect_back fallback_location: holidays_path, notice: "Ferien wurden erfolgreich gespeichert."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /holidays/1
  def update
    if @holiday.update(holiday_params)
      redirect_to holidays_path, notice: "Ferien wurden erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /holidays/1
  def destroy
    @holiday.destroy!
    redirect_to holidays_path, notice: "Ferien wurden entfernt."
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_holiday
      @holiday = Holiday.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def holiday_params
      params.expect(holiday: [ :title, :start_date, :end_date ])
    end
end
