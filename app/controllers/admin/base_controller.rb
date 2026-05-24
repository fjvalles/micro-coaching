module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :authenticate_admin_user!
    before_action :set_paper_trail_whodunnit

    def user_for_paper_trail
      current_admin_user&.email || "admin_unknown"
    end

    def info_for_paper_trail
      { source: "admin" }
    end
  end
end
