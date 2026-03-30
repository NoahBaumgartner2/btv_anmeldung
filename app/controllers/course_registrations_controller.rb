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
    @course_registration.payment_cleared = false

    # 1. Welchen Kurs möchte das Kind buchen?
    course = @course_registration.course

    # 2. Wie viele BESTÄTIGTE Plätze sind schon weg?
    bestaetigte_plaetze = course.course_registrations.where(status: 'bestätigt').count

    # 3. Die Wartelisten-Automatik!
    # Wir prüfen: Hat der Kurs ein Limit? UND Sind schon alle Plätze vergeben?
    if course.max_participants.present? && bestaetigte_plaetze >= course.max_participants
      @course_registration.status = 'warteliste'
      erfolgs_nachricht = "Der Kurs ist leider voll. Dein Kind wurde erfolgreich auf die Warteliste gesetzt!"
    else
      @course_registration.status = 'bestätigt'
      erfolgs_nachricht = "Fantastisch! Dein Kind hat einen festen Platz im Kurs."
    end

    if @course_registration.save
      redirect_to course_path(course), notice: erfolgs_nachricht
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
