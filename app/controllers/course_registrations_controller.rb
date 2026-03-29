class CourseRegistrationsController < ApplicationController
  # Nur eingeloggte User dürfen Kinder anmelden
  before_action :authenticate_user!

  def new
    @course_registration = CourseRegistration.new
    
    # Wenn wir von einer Kurs-Seite kommen, nehmen wir die ID direkt ins Formular mit
    if params[:course_id]
      @course_registration.course_id = params[:course_id]
    end
  end

  def create
    @course_registration = CourseRegistration.new(course_registration_params)
    
    # Standardwerte für neue Anmeldungen setzen
    @course_registration.status = 'warteliste'
    @course_registration.payment_cleared = false
    @course_registration.holiday_deduction_claimed = false

    if @course_registration.save
      # Wenn alles klappt, leiten wir zurück zum Kurs und zeigen eine Erfolgsmeldung
      redirect_to course_path(@course_registration.course), notice: 'Das Kind wurde erfolgreich für den Kurs angemeldet!'
    else
      # Wenn z.B. ein Feld fehlt, zeigen wir das Formular nochmal mit Fehlermeldungen
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Hier definieren wir, welche Felder aus dem Formular erlaubt sind (Sicherheits-Check)
  def course_registration_params
    params.require(:course_registration).permit(:course_id, :participant_id)
  end
end