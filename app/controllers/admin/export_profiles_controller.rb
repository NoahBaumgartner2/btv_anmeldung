module Admin
  class ExportProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!
    before_action :set_profile, only: %i[edit update destroy download]

    def index
      @export_profiles = ExportProfile.order(:name)
    end

    def new
      @export_profile = ExportProfile.new(
        format:      "csv",
        export_type: "teilnehmerliste",
        fields:      %w[last_name first_name date_of_birth user_email]
      )
    end

    def create
      @export_profile = ExportProfile.new(export_profile_params)
      if @export_profile.save
        redirect_to admin_export_profiles_path, notice: "Exportprofil \"#{@export_profile.name}\" wurde erstellt."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @export_profile.update(export_profile_params)
        redirect_to admin_export_profiles_path, notice: "Exportprofil \"#{@export_profile.name}\" wurde gespeichert."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @export_profile.destroy
      redirect_to admin_export_profiles_path, notice: "Exportprofil wurde gelöscht."
    end

    def download
      course = @export_profile.course

      if @export_profile.export_type == "anwesenheitsliste"
        unless course
          redirect_to admin_export_profiles_path, alert: "Kein Kurs zugewiesen – Download nicht möglich."
          return
        end
        date_range = @export_profile.effective_date_range
        data, mime, ext = case @export_profile.format
                          when "xlsx"
                            [ @export_profile.generate_attendance_xlsx(course, date_range),
                              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                              "xlsx" ]
                          when "pdf"
                            [ @export_profile.generate_attendance_pdf(course, date_range),
                              "application/pdf",
                              "pdf" ]
                          else
                            [ @export_profile.generate_attendance_csv(course, date_range),
                              "text/csv; charset=utf-8",
                              "csv" ]
                          end
        filename = "#{@export_profile.name.parameterize}-anwesenheit-#{Date.today.iso8601}.#{ext}"
      else
        participants = if course
                        course.participants.includes(:user, :courses)
                      else
                        Participant.includes(:user, :courses)
                      end
        data     = @export_profile.generate_csv(participants)
        mime     = "text/csv; charset=utf-8"
        filename = "#{@export_profile.name.parameterize}-#{Date.today.iso8601}.csv"
      end

      send_data data, filename: filename, type: mime, disposition: "attachment"
    end

    private

    def set_profile
      @export_profile = ExportProfile.find(params[:id])
    end

    def export_profile_params
      params.require(:export_profile).permit(
        :name, :format, :export_type, :course_id,
        :schedule, :recipient_email,
        :col_sep, :row_sep, :quote_char, :include_header,
        :date_range_type, :date_from, :date_to, :date_column_format,
        :attendance_symbols, :include_canceled_sessions,
        :sort_by, :extra_empty_rows,
        fields: [],
        include_summary_columns: []
      )
    end
  end
end
