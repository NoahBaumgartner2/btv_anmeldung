class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def admin
    authorize_admin!
    @courses = Course.includes(:course_registrations).order(start_date: :asc)

    q = params[:q].to_s.strip
    if q.length >= 2
      pattern = "%#{q}%"
      @participants = Participant.includes(:user)
                                 .joins(:user)
                                 .where(
                                   "participants.first_name ILIKE :p OR participants.last_name ILIKE :p OR users.email ILIKE :p OR CONCAT(participants.first_name, ' ', participants.last_name) ILIKE :p",
                                   p: pattern
                                 )
                                 .order(last_name: :asc, first_name: :asc)
                                 .limit(50)
    else
      @participants = Participant.none
    end
  end

  def trainer
    authorize_trainer!
    @trainer = Trainer.find_by(user: current_user)
    @assigned_courses = @trainer ? @trainer.courses.order(start_date: :asc) : []
  end
end