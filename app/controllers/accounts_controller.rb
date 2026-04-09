class AccountsController < ApplicationController
  before_action :authenticate_user!

  def show
    @participants = current_user.participants.includes(
      course_registrations: [ :course, { attendances: :training_session } ]
    )
    @newsletter_subscribed = current_user.newsletter_subscribed?
  end

  def subscribe_newsletter
    sub = NewsletterSubscriber.find_or_initialize_by(email: current_user.email.downcase.strip)
    sub.status = "subscribed"
    sub.source ||= "manual"
    sub.save
    redirect_to account_path, notice: "Du erhältst ab sofort wieder den BTV-Newsletter."
  end

  def unsubscribe_newsletter
    sub = current_user.newsletter_subscriber
    sub&.update(status: "unsubscribed")
    redirect_to account_path, notice: "Du wurdest vom BTV-Newsletter abgemeldet."
  end

  def destroy
    unless current_user.valid_password?(params[:password])
      redirect_to account_path, alert: "Falsches Passwort. Dein Konto wurde nicht gelöscht."
      return
    end

    user = current_user
    sign_out(user)
    user.destroy!

    redirect_to root_path, notice: "Dein Konto und alle Daten wurden gelöscht."
  end

  def export
    participants = current_user.participants.includes(
      course_registrations: [ :course, { attendances: :training_session } ]
    )

    payload = {
      exportiert_am: Time.current.iso8601,
      konto: {
        email: current_user.email,
        erstellt_am: current_user.created_at.iso8601,
        rolle: current_user.admin? ? "Admin" : (Trainer.exists?(user: current_user) ? "Trainer" : "Elternteil")
      },
      teilnehmer: participants.map do |p|
        {
          vorname: p.first_name,
          nachname: p.last_name,
          geburtsdatum: p.date_of_birth&.iso8601,
          geschlecht: p.gender,
          ahv_nummer: p.ahv_number.presence,
          anmeldungen: p.course_registrations.map do |cr|
            {
              kurs: cr.course.title,
              status: cr.status,
              zahlung_bestaetigt: cr.payment_cleared?,
              angemeldet_am: cr.created_at.iso8601,
              anwesenheiten: cr.attendances.map do |a|
                {
                  datum: a.training_session&.start_time&.iso8601,
                  status: a.status
                }
              end
            }
          end
        }
      end
    }

    send_data JSON.pretty_generate(payload),
              filename: "meine-daten-#{Date.today.iso8601}.json",
              type: "application/json",
              disposition: "attachment"
  end
end
