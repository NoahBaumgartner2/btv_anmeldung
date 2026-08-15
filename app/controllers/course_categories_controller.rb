# Admin-Übersicht: alle Kurskategorien mit Teilnehmerzahl, von wo aus eine
# E-Mail an alle Teilnehmer:innen einer ganzen Kategorie verschickt werden
# kann (kategorieübergreifend – anders als CoursesController#send_custom_email,
# das nur pro Einzelkurs arbeitet und auch Trainern offensteht).
class CourseCategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!

  def index
    courses = Course.all.includes(:course_registrations)
    grouped = courses.group_by { |c| c.category.presence || c.title.split("(").first.strip }

    @categories = grouped.map do |name, courses_in_category|
      recipient_count = courses_in_category
        .flat_map(&:course_registrations)
        .select { |r| CourseRegistration::OCCUPYING_STATUSES.include?(r.status) }
        .map(&:participant_id).uniq.size

      { name: name, course_count: courses_in_category.size, recipient_count: recipient_count }
    end.sort_by { |c| c[:name] }
  end

  def send_email
    category = params[:category].to_s
    subject  = params[:subject].to_s.strip
    body     = params[:body].to_s.strip

    if subject.blank? || body.blank?
      return redirect_to course_categories_path, alert: "Betreff und Nachricht dürfen nicht leer sein."
    end

    courses = Course.all.select { |c| (c.category.presence || c.title.split("(").first.strip) == category }
    regs = courses
      .flat_map(&:course_registrations)
      .select { |r| CourseRegistration::OCCUPYING_STATUSES.include?(r.status) }
      .uniq(&:participant_id)

    regs.each { |reg| CourseRegistrationMailer.custom_message(reg, subject: subject, body: body, sender: current_user).deliver_later }
    redirect_to course_categories_path, notice: "E-Mail an #{regs.size} Teilnehmer in Kategorie „#{category}“ wurde in die Warteschlange gelegt."
  end
end
