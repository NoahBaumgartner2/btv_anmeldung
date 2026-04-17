class NewsletterSubscribersController < ApplicationController
  before_action :authenticate_user!, except: :unsubscribe
  before_action :authorize_admin!,   except: :unsubscribe

  def index
    @subscribed_count   = NewsletterSubscriber.subscribed.count
    @unsubscribed_count = NewsletterSubscriber.unsubscribed.count
    @total_count        = NewsletterSubscriber.count

    if params[:q].present?
      q = "%#{params[:q].strip.downcase}%"
      @results = NewsletterSubscriber
                   .where("LOWER(email) LIKE ? OR LOWER(name) LIKE ?", q, q)
                   .order(created_at: :desc)
                   .limit(100)
    end
  end

  def create
    @subscriber = NewsletterSubscriber.new(subscriber_params)
    if @subscriber.save
      redirect_to newsletter_subscribers_path, notice: "#{@subscriber.email} wurde hinzugefügt."
    else
      @subscribed_count   = NewsletterSubscriber.subscribed.count
      @unsubscribed_count = NewsletterSubscriber.unsubscribed.count
      @total_count        = NewsletterSubscriber.count
      render :index, status: :unprocessable_entity
    end
  end

  def update
    subscriber = NewsletterSubscriber.find(params[:id])
    new_status = subscriber.subscribed? ? "unsubscribed" : "subscribed"
    subscriber.update!(status: new_status)
    redirect_to newsletter_subscribers_path,
                notice: "#{subscriber.email} ist jetzt #{new_status == 'subscribed' ? 'angemeldet' : 'abgemeldet'}."
  end

  def destroy
    subscriber = NewsletterSubscriber.find(params[:id])
    subscriber.destroy
    redirect_to newsletter_subscribers_path, notice: "#{subscriber.email} wurde gelöscht."
  end

  def import
    file = params[:csv_file]
    unless file&.content_type&.in?(["text/csv", "text/plain", "application/vnd.ms-excel"])
      return redirect_to newsletter_subscribers_path, alert: "Bitte eine CSV-Datei hochladen."
    end

    added = 0
    skipped = 0
    errors = []

    begin
      CSV.foreach(file.path, headers: true, encoding: "UTF-8", liberal_parsing: true) do |row|
        # Unterstützt Spalten: email, name, status — oder einfach nur eine Spalte mit der E-Mail
        email  = (row["email"] || row["Email"] || row["E-Mail"] || row[0]).to_s.strip.downcase
        name   = (row["name"]  || row["Name"]  || row[1]).to_s.strip.presence
        status = (row["status"] || row["Status"] || "subscribed").to_s.strip.downcase
        status = "subscribed" unless NewsletterSubscriber::STATUSES.include?(status)

        next if email.blank?

        sub = NewsletterSubscriber.find_or_initialize_by(email: email)
        sub.name   = name   if name.present?
        sub.status = status
        sub.source = "csv_import"

        if sub.save
          added += 1
        else
          skipped += 1
          errors << "#{email}: #{sub.errors.full_messages.join(', ')}"
        end
      end
    rescue CSV::MalformedCSVError => e
      return redirect_to newsletter_subscribers_path, alert: "Die CSV-Datei ist ungültig und konnte nicht gelesen werden: #{e.message}"
    end

    msg = "#{added} #{added == 1 ? 'Adresse' : 'Adressen'} importiert"
    msg += ", #{skipped} übersprungen" if skipped > 0
    redirect_to newsletter_subscribers_path, notice: msg
  end

  def unsubscribe
    subscriber = NewsletterSubscriber.find_by(unsubscribe_token: params[:token])
    if subscriber
      subscriber.update!(status: "unsubscribed")
      render plain: "Du wurdest erfolgreich vom Newsletter abgemeldet.", status: :ok
    else
      render plain: "Ungültiger Abmeldelink.", status: :not_found
    end
  end

  def export
    subscribers = NewsletterSubscriber.order(:email)
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["email", "name", "status", "source", "erstellt_am"]
      subscribers.each do |s|
        csv << [s.email, s.name, s.status, s.source, s.created_at.strftime("%d.%m.%Y")]
      end
    end
    send_data csv_data, filename: "newsletter_empfaenger_#{Date.today}.csv", type: "text/csv"
  end

  private

  def subscriber_params
    params.require(:newsletter_subscriber).permit(:email, :name, :status)
  end
end
