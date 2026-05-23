class NewslettersController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_newsletter, only: %i[edit update destroy send_newsletter preview]

  def index
    @drafts = Newsletter.drafts.order(updated_at: :desc)
    @sent   = Newsletter.sent.order(sent_at: :desc)
  end

  def new
    @newsletter = Newsletter.new
  end

  def create
    @newsletter = Newsletter.new(newsletter_params)
    if @newsletter.save
      redirect_to edit_newsletter_path(@newsletter), notice: "Newsletter gespeichert."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @newsletter.update(newsletter_params)
      redirect_to edit_newsletter_path(@newsletter), notice: "Änderungen gespeichert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @newsletter.destroy
    redirect_to newsletters_path, notice: "Newsletter gelöscht."
  end

  def preview
    render :show, layout: false
  end

  def send_newsletter
    if @newsletter.sent?
      return redirect_to newsletters_path, alert: "Dieser Newsletter wurde bereits versendet."
    end

    recipients = NewsletterSubscriber.subscribed
    if recipients.none?
      return redirect_to newsletters_path, alert: "Keine aktiven Empfänger vorhanden."
    end

    count = 0
    recipients.each do |subscriber|
      NewsletterMailer.campaign(@newsletter, subscriber).deliver_later
      count += 1
    end

    @newsletter.update!(status: "sent", sent_at: Time.current, recipients_count: count)
    redirect_to newsletters_path,
                notice: "Newsletter an #{count} Empfänger in die Warteschlange gelegt."
  end

  private

  def set_newsletter
    @newsletter = Newsletter.find(params[:id])
  end

  def newsletter_params
    params.require(:newsletter).permit(:title, :subject, :body_html)
  end
end
