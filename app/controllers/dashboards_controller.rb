class DashboardsController < ApplicationController
  # Nur eingeloggte User dürfen ihr Profil sehen!
  before_action :authenticate_user!

  def show
    # 1. Suche alle Kinder, die zu diesem Account gehören
    @my_participants = Participant.where(user: current_user)
    
    # 2. Suche alle Kursanmeldungen für genau diese Kinder 
    # (und lade die Kurs-Infos direkt mit, das macht die Seite blitzschnell)
    @my_registrations = CourseRegistration.includes(:course, :participant).where(participant: @my_participants)
  end
end