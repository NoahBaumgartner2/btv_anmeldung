class CourseRegistrationsController < ApplicationController
  before_action :authenticate_user!
  # Sucht die Anmeldung anhand der ID in der URL, bevor edit, update oder destroy ausgeführt wird
  before_action :set_course_registration, only: [ :edit, :update, :destroy ]

  def new
    @course_registration = CourseRegistration.new
    if params[:course_id]
      @course_registration.course_id = params[:course_id]
    end
  end

  def create
    @course_registration = CourseRegistration.new(course_registration_params)
    @course_registration.status = "warteliste"
    @course_registration.payment_cleared = false

    if @course_registration.save
      redirect_to course_path(@course_registration.course), notice: "Das Kind wurde erfolgreich für den Kurs angemeldet!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # NEU: Das Formular zum Bearbeiten laden
  def edit
  end

  # NEU: Die Änderungen in der Datenbank speichern
  def update
    if @course_registration.update(course_registration_params)
      redirect_to course_path(@course_registration.course), notice: "Anmeldung wurde erfolgreich aktualisiert!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # NEU: Eine Anmeldung komplett löschen/stornieren
  def destroy
    course = @course_registration.course
    @course_registration.destroy
    redirect_to course_path(course), notice: "Die Anmeldung wurde gelöscht."
  end

  private

  def set_course_registration
    @course_registration = CourseRegistration.find(params[:id])
  end

  # Der Türsteher: Erlaubt jetzt auch Status und Bezahlung!
  def course_registration_params
    params.require(:course_registration).permit(:course_id, :participant_id, :status, :payment_cleared, :holiday_deduction_claimed)
  end
end
