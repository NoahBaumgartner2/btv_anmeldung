# Admin-Funktion für Nachforderungen (nachträgliche Zusatzbeträge, z.B. wenn
# ein Rabatt fälschlich angewendet wurde und der Differenzbetrag nachverlangt
# werden muss - siehe docs/rabatt-audit-q4-2026.md). Formular: Zeitraum ->
# Kategorie -> Kurs auswählen (kaskadiert client-seitig, siehe course-picker
# Stimulus-Controller), danach erscheint die vollständige Teilnehmerliste
# dieses Kurses zur Auswahl - bewusst KEINE freie Personensuche, damit nicht
# beliebige Personen ausserhalb des betroffenen Kurses ausgewählt werden
# können. Betrag/Beschreibung/Erklärtext gelten für alle ausgewählten
# Personen; pro Person entsteht eine eigene Nachforderung samt Mail.
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
      @courses = Course.includes(:term).order(title: :asc)
    end

    def create
      @courses = Course.includes(:term).order(title: :asc)

      course = Course.find_by(id: params[:course_id])
      amount = params[:amount].to_s.tr(",", ".").to_f
      participant_ids = Array(params[:participant_ids]).reject(&:blank?)

      if course.nil?
        return render_new_with_error("Bitte einen Kurs auswählen.")
      end
      if participant_ids.empty?
        return render_new_with_error("Bitte mindestens eine Person auswählen.")
      end
      if amount <= 0
        return render_new_with_error("Bitte einen gültigen Betrag angeben.")
      end
      if params[:description].to_s.strip.blank?
        return render_new_with_error("Bitte eine Beschreibung angeben.")
      end

      # Nur Personen, die tatsächlich (nicht storniert) im gewählten Kurs
      # angemeldet sind, dürfen belastet werden - unabhängig davon, was das
      # Formular schickt (siehe Klassenkommentar).
      registered_ids = course.course_registrations.where.not(status: "storniert").pluck(:participant_id)
      selected_participants = Participant.where(id: participant_ids.map(&:to_i) & registered_ids)

      if selected_participants.none?
        return render_new_with_error("Keine der ausgewählten Personen ist in diesem Kurs angemeldet.")
      end

      amount_cents = (amount * 100).round
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
  end
end
