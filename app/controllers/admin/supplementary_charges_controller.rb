# Admin-Funktion für Nachforderungen (nachträgliche Zusatzbeträge, z.B. wenn
# ein Rabatt fälschlich angewendet wurde und der Differenzbetrag nachverlangt
# werden muss - siehe docs/rabatt-audit-q4-2026.md). Ein Formular deckt sowohl
# den Einzelfall als auch das Massen-Szenario ab (mehrere betroffene Personen,
# derselbe Betrag/Kurs/Grund): Teilnehmer per Suche finden, per Checkbox
# auswählen, einmal Betrag/Kurs/Beschreibung/Erklärtext eintragen - pro
# ausgewählter Person entsteht eine eigene Nachforderung samt Mail.
module Admin
  class SupplementaryChargesController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    def index
      @charges = SupplementaryCharge.includes(:participant, :course)
        .order(created_at: :desc)
        .limit(100)
    end

    def new
      @courses = Course.order(title: :asc)
      @q = params[:q].to_s.strip
      @preselected_id = params[:participant_id].presence
      @participants = if @q.present?
        search_participants(@q)
      elsif @preselected_id
        Participant.includes(:user).where(id: @preselected_id)
      else
        Participant.none
      end
    end

    def create
      @courses = Course.order(title: :asc)
      @q = params[:q].to_s.strip
      @participants = search_participants(@q)

      participant_ids = Array(params[:participant_ids]).reject(&:blank?)
      course = Course.find_by(id: params[:course_id])
      amount = params[:amount].to_s.tr(",", ".").to_f

      if participant_ids.empty?
        return render_new_with_error("Bitte mindestens eine Person auswählen.")
      end
      if course.nil?
        return render_new_with_error("Bitte einen Kurs auswählen.")
      end
      if amount <= 0
        return render_new_with_error("Bitte einen gültigen Betrag angeben.")
      end
      if params[:description].to_s.strip.blank?
        return render_new_with_error("Bitte eine Beschreibung angeben.")
      end

      amount_cents = (amount * 100).round
      selected_participants = Participant.where(id: participant_ids)

      if selected_participants.none?
        return render_new_with_error("Keine gültigen Personen gefunden. Bitte erneut auswählen.")
      end

      created = []
      selected_participants.find_each do |participant|
        charge = SupplementaryCharge.create!(
          participant:  participant,
          course:       course,
          created_by:   current_user,
          amount_cents: amount_cents,
          description:  params[:description],
          explanation:  params[:explanation]
        )
        created << charge
        SupplementaryChargeMailer.payment_request(charge).deliver_later
      end

      redirect_to admin_supplementary_charges_path,
        notice: "#{created.size} Nachforderung(en) über #{created.first.amount_display} erstellt, Mails werden verschickt."
    end

    private

    def render_new_with_error(message)
      flash.now[:alert] = message
      render :new, status: :unprocessable_entity
    end

    def search_participants(q)
      return Participant.none if q.length < 2

      pattern = "%#{q}%"
      Participant.includes(:user)
        .joins(:user)
        .where(
          "participants.first_name ILIKE :p OR participants.last_name ILIKE :p OR users.email ILIKE :p OR CONCAT(participants.first_name, ' ', participants.last_name) ILIKE :p",
          p: pattern
        )
        .order(last_name: :asc, first_name: :asc)
        .limit(50)
    end
  end
end
