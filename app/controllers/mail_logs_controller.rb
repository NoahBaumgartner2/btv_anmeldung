class MailLogsController < ApplicationController
  PER_PAGE = 20

  before_action :authenticate_user!
  before_action :authorize_trainer!

  def index
    visible = MailLog.visible_to(current_user)
    @courses = visible.where.not(course_id: nil).group(:course_id)
                      .pluck(:course_id, Arel.sql("MAX(course_title)")).sort_by { |_, title| title.to_s.downcase }
    @kinds = visible.distinct.pluck(:kind).map { |kind| [ MailLog.new(kind: kind).label, kind ] }.sort
    @any_logs = visible.exists?
    @filtered = %i[q course_id kind from to].any? { |key| params[key].present? }

    logs = filter(visible)
    @total = logs.count
    @page = params[:page].to_i.clamp(1, [ (@total.to_f / PER_PAGE).ceil, 1 ].max)
    @logs = logs.order(created_at: params[:sort] == "oldest" ? :asc : :desc, id: :desc)
                .limit(@page * PER_PAGE)
    @shown = [ @page * PER_PAGE, @total ].min
  end

  private

  def filter(logs)
    logs = logs.where(course_id: params[:course_id]) if params[:course_id].present?
    logs = logs.where(kind: params[:kind]) if params[:kind].present?
    logs = logs.search(params[:q].strip, search_all: current_user.admin?) if params[:q].present?
    from = parse_date(params[:from])
    to = parse_date(params[:to])
    logs = logs.where(created_at: from.in_time_zone.beginning_of_day..) if from
    logs = logs.where(created_at: ..to.in_time_zone.end_of_day) if to
    logs
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end
end
