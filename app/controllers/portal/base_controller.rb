module Portal
  class BaseController < ApplicationController
    layout "portal"
    before_action :authenticate_participant!

    private

    def authenticate_participant!
      return if current_participant

      redirect_to portal_login_path, alert: "Inicia sesión para ver tu cuenta."
    end
  end
end
