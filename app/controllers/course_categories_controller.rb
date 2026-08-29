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

      # find_or_create_by, damit jede Kategorie einen echten Datensatz zum
      # Bild-Anhängen hat, ohne dass die Kategorien-Verwaltung dupliziert werden muss.
      record = CourseCategory.find_or_create_by!(name: name)

      { name: name, course_count: courses_in_category.size, recipient_count: recipient_count, record: record }
    end.sort_by { |c| c[:name] }
  end

  def update_image
    @course_category = CourseCategory.find(params[:id])

    if @course_category.update(course_category_params)
      redirect_to course_categories_path, notice: "Bild für „#{@course_category.name}“ wurde gespeichert."
    else
      redirect_to course_categories_path, alert: @course_category.errors.full_messages.join(", ")
    end
  end

  def destroy_image
    @course_category = CourseCategory.find(params[:id])
    @course_category.image.purge
    redirect_to course_categories_path, notice: "Bild für „#{@course_category.name}“ wurde entfernt."
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

  private

  def course_category_params
    params.require(:course_category).permit(:image)
  end
end
