class CookieConsentsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def create
    value = params[:consent] == "all" ? "all" : "necessary"
    cookies[:cookie_consent] = {
      value: value,
      expires: 1.year.from_now,
      httponly: true,
      secure: Rails.env.production?
    }
    head :no_content
  end
end
