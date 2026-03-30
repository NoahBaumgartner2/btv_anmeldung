class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def admin
    authorize_admin! # Nur Reto darf hier rein!
    @courses = Course.order(start_date: :asc)
    @trainers = Trainer.all
    
    # NEU: Lade alle Teilnehmer, alphabetisch sortiert nach Nachname, inkl. Eltern-Account (User)
    @participants = Participant.includes(:user).order(last_name: :asc, first_name: :asc)
  end

  def trainer
    authorize_trainer!
    @trainer = Trainer.find_by(user: current_user)
    @assigned_courses = @trainer ? @trainer.courses.order(start_date: :asc) : []
  end
end