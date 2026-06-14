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

    private

    # Superadmin-only gate. Use as a before_action on actions/controllers that
    # manage privileged surface (settings, technical docs, superadmin accounts).
    def require_superadmin
      head :forbidden unless current_admin_user&.superadmin?
    end
  end
end
