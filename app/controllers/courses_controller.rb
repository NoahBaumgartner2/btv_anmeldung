class CoursesController < ApplicationController
  # Für neue Kurse oder Bearbeitung MUSS man Admin sein
  before_action :authorize_admin!, except: [:index, :show]
  # GET /courses or /courses.json
  before_action :authorize_trainer!, only: [:manage]
  before_action :set_course, only: %i[ show edit update destroy generate_trainings create_generated_trainings manage ]
  def index
    @courses = Course.all
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
        format.html { redirect_to @course, notice: "Course was successfully created." }
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
        format.html { redirect_to @course, notice: "Course was successfully updated.", status: :see_other }
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
      format.html { redirect_to courses_path, notice: "Course was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # Zeigt das Formular für den Generator an
  def generate_trainings
  end

  # Führt die Magie aus!
  def create_generated_trainings
    @course = Course.find(params[:id])
    wochentag = params[:day_of_week].to_i # 0=So, 1=Mo...
    uhrzeit = params[:start_time] # Format "18:00"

    holidays = Holiday.all
    current_date = @course.start_date.to_date
    end_date = @course.end_date.to_date
    created_count = 0

    while current_date <= end_date
      if current_date.wday == wochentag
        # Check: Liegt das Datum in den Ferien?
        is_holiday = holidays.any? { |h| current_date >= h.start_date && current_date <= h.end_date }

        exists = @course.training_sessions.where("start_time::date = ?", current_date).exists?

        unless is_holiday
          # Zeit kombinieren
          h, m = uhrzeit.split(":")
          full_start = current_date.in_time_zone.change(hour: h, min: m)

          @course.training_sessions.create!(start_time: full_start)
          created_count += 1
        end
      end
      current_date += 1.day
    end

    redirect_to @course, notice: "#{created_count} Trainings wurden automatisch erstellt (Ferien wurden übersprungen)!"
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
  params.require(:course).permit(:title, :description, :start_date, :end_date, :location, :registration_type, :has_payment, :has_ticketing, :registration_mode, :max_participants, trainer_ids: [])
  end
end
