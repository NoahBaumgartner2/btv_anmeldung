require "csv"

module Admin
  class ReportsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    def show
      @courses = Course.order(:title)
      @krabbel_courses = Course.where(category: "Krabbel Gym").order(:title)
    end

    def btv_teilnehmerzahl
      courses = Course.includes(:course_registrations).order(:title)
      csv = CSV.generate(col_sep: ";") do |csv|
        csv << ["Kurs", "Kategorie", "Bestätigt", "Warteliste", "Total Anmeldungen"]
        courses.each do |course|
          bestaetigt = course.course_registrations.count { |r| r.status == "bestätigt" }
          warteliste = course.course_registrations.count { |r| r.status == "warteliste" }
          total      = course.course_registrations.count
          csv << [course.title, course.category, bestaetigt, warteliste, total]
        end
      end
      send_data "\xEF\xBB\xBF#{csv}",
        filename: "btv-teilnehmerzahl-#{Date.today}.csv",
        type: "text/csv; charset=utf-8",
        disposition: "attachment"
    end

    def sportfonds_breitensport
      course_id = params[:course_id].presence
      scope = CourseRegistration
                .joins(:course, :participant)
                .includes(participant: :user, course: {})
                .where(status: "bestätigt")
                .where.not(courses: { category: "Krabbel Gym" })
      scope = scope.where(course_id: course_id) if course_id
      csv = CSV.generate(col_sep: ";") do |csv|
        csv << ["Vorname", "Nachname", "Geburtsdatum", "Geschlecht", "Nationalität", "PLZ", "Wohnort", "Kurs", "Kategorie"]
        scope.each do |reg|
          p = reg.participant
          csv << [
            p.first_name, p.last_name,
            p.date_of_birth&.strftime("%d.%m.%Y"),
            p.gender, p.nationality, p.zip_code, p.city,
            reg.course.title, reg.course.category
          ]
        end
      end
      send_data "\xEF\xBB\xBF#{csv}",
        filename: "sportfonds-breitensport-#{Date.today}.csv",
        type: "text/csv; charset=utf-8",
        disposition: "attachment"
    end

    def sportfonds_spitzensport
      course_id = params[:course_id].presence
      scope = CourseRegistration
                .joins(:course, :participant)
                .includes(participant: :user, course: {})
                .where(status: "bestätigt")
      scope = scope.where(course_id: course_id) if course_id
      csv = CSV.generate(col_sep: ";") do |csv|
        csv << ["Vorname", "Nachname", "Geburtsdatum", "Geschlecht", "Nationalität", "PLZ", "Wohnort", "AHV-Nummer", "Telefon", "Kurs", "Kategorie"]
        scope.each do |reg|
          p = reg.participant
          csv << [
            p.first_name, p.last_name,
            p.date_of_birth&.strftime("%d.%m.%Y"),
            p.gender, p.nationality, p.zip_code, p.city,
            p.ahv_number, p.phone_number,
            reg.course.title, reg.course.category
          ]
        end
      end
      send_data "\xEF\xBB\xBF#{csv}",
        filename: "sportfonds-spitzensport-#{Date.today}.csv",
        type: "text/csv; charset=utf-8",
        disposition: "attachment"
    end

    def krabbel_gym_statistik
      course_id = params[:course_id].presence
      scope = TrainingSession
                .joins(:course)
                .includes(attendances: { course_registration: :participant }, course: {})
                .where(courses: { category: "Krabbel Gym" })
      scope = scope.where(course_id: course_id) if course_id
      scope = scope.order(:start_time)
      csv = CSV.generate(col_sep: ";") do |csv|
        csv << ["Datum", "Uhrzeit", "Kurs", "Anwesend", "Abwesend", "Abgemeldet", "Total erfasst"]
        scope.each do |session|
          anwesend   = session.attendances.count { |a| a.status == "anwesend" }
          abwesend   = session.attendances.count { |a| a.status == "abwesend" }
          abgemeldet = session.attendances.count { |a| a.status == "abgemeldet" }
          csv << [
            session.start_time.strftime("%d.%m.%Y"),
            session.start_time.strftime("%H:%M"),
            session.course.title,
            anwesend, abwesend, abgemeldet,
            anwesend + abwesend + abgemeldet
          ]
        end
      end
      send_data "\xEF\xBB\xBF#{csv}",
        filename: "krabbel-gym-statistik-#{Date.today}.csv",
        type: "text/csv; charset=utf-8",
        disposition: "attachment"
    end
  end
end
