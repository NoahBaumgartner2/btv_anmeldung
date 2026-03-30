class HolidaysController < ApplicationController
  before_action :set_holiday, only: %i[ show edit update destroy ]

  # GET /holidays or /holidays.json
  def index
    @holidays = Holiday.all
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

  def destroy
    @holiday = Holiday.find(params[:id])
    @holiday.destroy
    redirect_back fallback_location: holidays_path, notice: "Ferien wurden entfernt."
  end

  # PATCH/PUT /holidays/1 or /holidays/1.json
  def update
    respond_to do |format|
      if @holiday.update(holiday_params)
        format.html { redirect_to @holiday, notice: "Holiday was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @holiday }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @holiday.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /holidays/1 or /holidays/1.json
  def destroy
    @holiday.destroy!

    respond_to do |format|
      format.html { redirect_to holidays_path, notice: "Holiday was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
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
