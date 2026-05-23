class PagesController < ApplicationController
  def privacy; end
  def impressum; end

  def home
    if user_signed_in?
      if current_user.admin?
        redirect_to dashboards_admin_path
      elsif Trainer.exists?(user: current_user)
        redirect_to dashboards_trainer_path
      else
        redirect_to participants_path
      end
      return
    end

    @courses = Course.includes(:course_registrations)
                     .where("end_date >= ? OR end_date IS NULL OR registration_mode = ?", Date.today, "single_session")
                     .order(:title)
  end
end
