class CoursesController < ApplicationController
  # Für neue Kurse oder Bearbeitung MUSS man Admin sein
  before_action :authorize_admin!, except: [:index, :show, :manage]
  # GET /courses or /courses.json
  before_action :authorize_trainer!, only: [:manage]
  before_action :set_course, only: %i[ show edit update destroy generate_trainings create_generated_trainings manage ]
  def index
    @courses = Course.includes(:course_registrations).order(:title)
  end

  # GET /courses/1 or /courses/1.json
  def show
  end

  # GET /courses/new
  def new
    @course = Course.new
  end

  # GET /courses/1/edit
  def edit
  end

  # POST /courses or /courses.json
  def create
    @course = Course.new(course_params)

    respond_to do |format|
      if @course.save
        format.html { redirect_to @course, notice: "Kurs wurde erfolgreich erstellt." }
        format.json { render :show, status: :created, location: @course }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @course.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /courses/1 or /courses/1.json
  def update
    respond_to do |format|
      if @course.update(course_params)
        format.html { redirect_to @course, notice: "Kurs wurde erfolgreich aktualisiert.", status: :see_other }
        format.json { render :show, status: :ok, location: @course }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @course.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /courses/1 or /courses/1.json
  def destroy
    @course.destroy!

    respond_to do |format|
      format.html { redirect_to courses_path, notice: "Kurs wurde erfolgreich gelöscht.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # Zeigt das Formular für den Generator an
  def generate_trainings
  end

  # Führt die Magie aus!
  def create_generated_trainings
    unless @course.start_date.present? && @course.end_date.present?
      redirect_to generate_trainings_course_path(@course),
                  alert: "Dieser Kurs hat kein Start- oder Enddatum. Bitte zuerst den Kurs bearbeiten.",
                  status: :see_other and return
    end

    unless params[:start_hour].present? && params[:day_of_week].present?
      redirect_to generate_trainings_course_path(@course),
                  alert: "Bitte Wochentag und Startzeit auswählen.",
                  status: :see_other and return
    end

    wochentag = params[:day_of_week].to_i
    start_uhrzeit = "#{params[:start_hour]}:#{format('%02d', params[:start_minute].to_i)}"
    end_uhrzeit   = params[:end_hour].present? ? "#{params[:end_hour]}:#{format('%02d', params[:end_minute].to_i)}" : nil

    # Ausgewählte DB-Ferien (Checkboxen)
    selected_holiday_ids = Array(params[:holiday_ids]).map(&:to_i)
    holidays = Holiday.where(id: selected_holiday_ids)

    # Manuell eingegebene Ferien
    extra_holidays = Array(params[:extra_holidays]&.values).filter_map do |h|
      next unless h[:start_date].present? && h[:end_date].present?
      { start_date: Date.parse(h[:start_date]), end_date: Date.parse(h[:end_date]) }
    rescue ArgumentError
      nil
    end

    current_date = @course.start_date.to_date
    end_date     = @course.end_date.to_date
    created_count  = 0
    skipped_count  = 0

    while current_date <= end_date
      if current_date.wday == wochentag
        is_holiday = holidays.any? { |h| current_date >= h.start_date && current_date <= h.end_date } ||
                     extra_holidays.any? { |h| current_date >= h[:start_date] && current_date <= h[:end_date] }
        exists     = @course.training_sessions.where("start_time::date = ?", current_date).exists?

        if is_holiday || exists
          skipped_count += 1
        else
          sh, sm = start_uhrzeit.split(":").map(&:to_i)
          full_start = current_date.in_time_zone.change(hour: sh, min: sm)

          full_end = if end_uhrzeit.present?
            eh, em = end_uhrzeit.split(":").map(&:to_i)
            current_date.in_time_zone.change(hour: eh, min: em)
          end

          @course.training_sessions.create!(start_time: full_start, end_time: full_end)
          created_count += 1
        end
      end
      current_date += 1.day
    end

    notice = "#{created_count} #{"Training".pluralize(created_count)} erstellt"
    notice += ", #{skipped_count} übersprungen (Ferien oder bereits vorhanden)" if skipped_count > 0

    redirect_to manage_course_path(@course), notice: notice, status: :see_other
  end

  def manage
    # Lädt einfach die Verwaltungs-Seite für diesen Kurs
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_course
      @course = Course.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def course_params
      params.require(:course).permit(:title, :description, :start_date, :end_date, :location, :registration_type, :has_payment, :price_chf, :has_ticketing, :is_js_training, :registration_mode, :max_participants, :min_age, :max_age, :requires_ahv_number, :requires_js_person_number, :requires_nationality, :requires_mother_tongue, :requires_zip_code, :requires_city, :requires_country, :requires_street, :default_start_hour, :default_start_minute, :default_end_hour, :default_end_minute, trainer_ids: [], payment_methods: [])
    end
end
