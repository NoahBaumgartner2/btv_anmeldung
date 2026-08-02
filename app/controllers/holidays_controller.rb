class HolidaysController < ApplicationController
  before_action :authorize_admin!
  before_action :set_holiday_type
  before_action :set_holiday, only: %i[ edit update destroy ]

  # GET /holiday_types/:holiday_type_id/holidays/new
  def new
    @holiday = @holiday_type.holidays.new
  end

  # GET /holiday_types/:holiday_type_id/holidays/1/edit
  def edit
  end

  # POST /holiday_types/:holiday_type_id/holidays
  def create
    @holiday = @holiday_type.holidays.new(holiday_params)
    if @holiday.save
      redirect_to holiday_type_path(@holiday_type), notice: "Termin wurde erfolgreich gespeichert."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /holiday_types/:holiday_type_id/holidays/1
  def update
    if @holiday.update(holiday_params)
      redirect_to holiday_type_path(@holiday_type), notice: "Termin wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /holiday_types/:holiday_type_id/holidays/1
  def destroy
    @holiday.destroy!
    redirect_to holiday_type_path(@holiday_type), notice: "Termin wurde entfernt."
  end

  private
    def set_holiday_type
      @holiday_type = HolidayType.find(params.expect(:holiday_type_id))
    end

    def set_holiday
      @holiday = @holiday_type.holidays.find(params.expect(:id))
    end

    def holiday_params
      params.expect(holiday: [ :start_date, :end_date ])
    end
end
