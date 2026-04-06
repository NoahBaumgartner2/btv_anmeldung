module Admin
  class ExportProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!
    before_action :set_profile, only: %i[edit update destroy]

    def index
      @export_profiles = ExportProfile.order(:name)
    end

    def new
      @export_profile = ExportProfile.new(format: "csv", fields: %w[last_name first_name date_of_birth user_email])
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

    private

    def set_profile
      @export_profile = ExportProfile.find(params[:id])
    end

    def export_profile_params
      params.require(:export_profile).permit(
        :name, :format, :course_id,
        :schedule, :recipient_email,
        :col_sep, :row_sep, :quote_char, :include_header,
        fields: []
      )
    end
  end
end
