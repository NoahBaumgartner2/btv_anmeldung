class ClubColorsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    # first gibt nil zurück wenn die Tabelle leer ist → Fallback auf leere Instanz mit Defaults
    @club_setting = ClubSetting.first || ClubSetting.new
    # Lang cachen – URL enthält ?v=<updated_at>, ändert sich bei Farbänderung automatisch
    expires_in 1.year, public: true
    render layout: false, content_type: "text/css"
  end
end
