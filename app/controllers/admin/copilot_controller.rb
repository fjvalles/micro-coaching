module Admin
  # Ops copilot — superadmin-only chat that reads the DB and proposes gated
  # business actions. Phase 1: foundation + routing + transcript rendering.
  # The OpenAI tool-calling loop and act-tool execution land in later phases
  # (Copilot::AgentRunner / CopilotAgentJob).
  class CopilotController < BaseController
    before_action :require_superadmin
    before_action :require_copilot_enabled
    before_action :set_session, only: %i[show message]
    before_action :set_action, only: %i[approve_action reject_action]

    def index
      @sessions = current_admin_user.copilot_sessions.order(created_at: :desc).limit(50)
    end

    def create
      session = current_admin_user.copilot_sessions.create!(status: :active)
      redirect_to admin_copilot_session_path(session)
    end

    def show
      @messages = @session.copilot_messages
      @pending_actions = @session.copilot_pending_actions.awaiting
    end

    def message
      body = params.require(:content).to_s.strip
      return redirect_to(admin_copilot_session_path(@session)) if body.blank?

      @session.copilot_messages.create!(role: :user, content: body)
      CopilotAgentJob.perform_later(@session.id)
      redirect_to admin_copilot_session_path(@session)
    end

    def approve_action
      @action.update!(approved_by: current_admin_user.email)
      result = Copilot::ActExecutor.new(@action).call
      flash[:alert] = "Acción falló: #{result.data[:error]}" unless result.ok?
      redirect_to admin_copilot_session_path(@action.copilot_session)
    end

    def reject_action
      @action.update!(status: :rejected, approved_by: current_admin_user.email)
      redirect_to admin_copilot_session_path(@action.copilot_session)
    end

    private

    def set_session
      @session = current_admin_user.copilot_sessions.find(params[:id])
    end

    def set_action
      @action = CopilotPendingAction.find(params[:id])
      head :forbidden unless @action.copilot_session.admin_user_id == current_admin_user.id
    end

    def require_copilot_enabled
      return if Setting.fetch("copilot_enabled")

      redirect_to admin_root_path, alert: "El copiloto está desactivado (copilot_enabled)."
    end
  end
end
