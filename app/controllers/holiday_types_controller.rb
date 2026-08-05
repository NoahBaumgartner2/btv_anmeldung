class HolidayTypesController < ApplicationController
  before_action :authorize_admin!
  before_action :set_holiday_type, only: %i[ edit update destroy ]

  # GET /holiday_types
  def index
    @holiday_types = HolidayType.order(:name).includes(:holidays)
  end

  # GET /holiday_types/new
  def new
    @holiday_type = HolidayType.new
  end

  # POST /holiday_types
  def create
    @holiday_type = HolidayType.new(holiday_type_params)
    if @holiday_type.save
      redirect_to holiday_types_path, notice: "Ferien-Typ wurde erfolgreich erstellt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /holiday_types/1/edit
  def edit
  end

  # PATCH/PUT /holiday_types/1
  def update
    if @holiday_type.update(holiday_type_params)
      redirect_to holiday_types_path, notice: "Ferien-Typ wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /holiday_types/1
  def destroy
    @holiday_type.destroy!
    redirect_to holiday_types_path, notice: "Ferien-Typ wurde entfernt."
  end

  private
    def set_holiday_type
      @holiday_type = HolidayType.find(params.expect(:id))
    end

    def holiday_type_params
      params.expect(holiday_type: [ :name ])
    end
end
