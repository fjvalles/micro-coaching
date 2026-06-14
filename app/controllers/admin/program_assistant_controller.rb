module Admin
  # Asistente IA de programas — chat embebido (modal en /admin/programs) que lee,
  # crea y edita programas conversacionalmente. Mismo patrón que el Copiloto:
  # las acciones de escritura (crear/editar) quedan como propuesta y solo se
  # ejecutan cuando un admin las aprueba (ProgramAssistant::ActExecutor).
  class ProgramAssistantController < BaseController
    before_action :require_assistant_enabled
    before_action :set_session, only: %i[show message reset]
    before_action :set_action, only: %i[approve_action reject_action]

    # GET /admin/program_assistant — renders the chat inside the modal turbo-frame.
    # Reuses the admin's active session (one open thread per admin) or creates one.
    def show
      @messages = @session.program_assistant_messages
      render partial: "admin/program_assistant/chat", locals: { session: @session, messages: @messages }
    end

    # POST /admin/program_assistant/message — append the user turn and run the agent.
    def message
      body = params.require(:content).to_s.strip
      return head(:no_content) if body.blank?

      @session.program_assistant_messages.create!(role: :user, content: body)
      ProgramAssistantAgentJob.perform_later(@session.id)
      head :no_content
    end

    # POST /admin/program_assistant/reset — archive the open thread and start fresh.
    def reset
      @session.update!(status: :archived)
      redirect_to admin_program_assistant_path
    end

    def approve_action
      @action.update!(approved_by: current_admin_user.email)
      result = ProgramAssistant::ActExecutor.new(@action).call
      flash[:alert] = "Acción falló: #{result.data[:error]}" unless result.ok?
      head :no_content
    end

    def reject_action
      @action.update!(status: :rejected, approved_by: current_admin_user.email)
      head :no_content
    end

    private

    def set_session
      @session = current_admin_user.program_assistant_sessions.active.order(:created_at).last ||
                 current_admin_user.program_assistant_sessions.create!(status: :active)
    end

    def set_action
      @action = ProgramAssistantPendingAction.find(params[:id])
      head :forbidden unless @action.program_assistant_session.admin_user_id == current_admin_user.id
    end

    def require_assistant_enabled
      return if Setting.fetch("program_assistant_enabled")

      render plain: "El Asistente IA está desactivado (program_assistant_enabled).", status: :forbidden
    end
  end
end
