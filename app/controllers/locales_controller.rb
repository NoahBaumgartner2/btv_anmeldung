class LocalesController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def update
    locale = params[:locale].to_sym
    if I18n.available_locales.include?(locale)
      session[:locale] = locale
    end
    redirect_back fallback_location: root_path
  end
end
