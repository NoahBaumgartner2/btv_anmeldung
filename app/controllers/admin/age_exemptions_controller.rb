# Altersübersicht pro Zeitraum (Quartal/Semester): zeigt, wer in den Kursen
# des gewählten Zeitraums über dem Höchstalter liegt - getrennt nach "war schon
# vorher zu alt" und "wird jetzt zu alt". Pro Person kann eine Altersausnahme
# erteilt bzw. wieder entzogen werden (AgeExemption), womit sie sich trotz
# Überalterung im Vorrang-Fenster neu anmelden darf.
#
# Bewusst ohne automatische Benachrichtigung: die Ausnahme wird nur intern
# gesetzt, die Eltern werden vom Verein selbst informiert.
module Admin
  class AgeExemptionsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    def index
      @terms  = Term.order(start_date: :desc)
      @term   = params[:term_id].present? ? Term.find_by(id: params[:term_id]) : default_term
      @groups = AgeTransitionReport.for(@term)
      # Kurse ohne Zeitraum (laufend, z.B. Krabbelgym) laufen nie ab und
      # tauchen daher in keinem Zeitraum-Filter auf - trotzdem immer separat
      # anzeigen, unabhängig von der Zeitraum-Auswahl oben.
      @termless_groups = AgeTransitionReport.termless
    end

    def create
      participant = Participant.find_by(id: params[:participant_id])
      course      = Course.find_by(id: params[:course_id])

      if participant.nil? || course.nil?
        return redirect_back_to_index(alert: "Person oder Kurs nicht gefunden.")
      end

      exemption = AgeExemption.find_or_initialize_by(participant: participant, course: course)
      exemption.granted_by = current_user
      exemption.note = params[:note]

      if exemption.save
        redirect_back_to_index(
          notice: "Altersausnahme für #{participant.first_name} #{participant.last_name} " \
                  "in \"#{course.title}\" erteilt."
        )
      else
        redirect_back_to_index(alert: "Altersausnahme konnte nicht erteilt werden.")
      end
    end

    def destroy
      exemption = AgeExemption.find_by(id: params[:id])
      return redirect_back_to_index(alert: "Altersausnahme nicht gefunden.") if exemption.nil?

      participant = exemption.participant
      exemption.destroy!
      redirect_back_to_index(
        notice: "Altersausnahme für #{participant.first_name} #{participant.last_name} entfernt."
      )
    end

    private

    def redirect_back_to_index(flash_options)
      redirect_to admin_age_exemptions_path(term_id: params[:term_id]), **flash_options
    end

    # Standardmässig der nächste anstehende Zeitraum - dort entscheidet sich,
    # wer herauswächst. Fallback: der zuletzt begonnene.
    def default_term
      Term.where("start_date >= ?", Date.current).order(:start_date).first ||
        Term.order(start_date: :desc).first
    end
  end
end
