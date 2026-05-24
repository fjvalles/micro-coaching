module Admin
  class PendingResponsesController < BaseController
    before_action :set_pending, only: [ :show, :update, :approve, :send_now, :reject ]

    def index
      @pendings = PendingResponse.kept.includes(:participant).pending_action.recent_first
      @history  = PendingResponse.kept.includes(:participant).where(status: %w[sent rejected]).order(acted_at: :desc).limit(20)
    end

    def show
    end

    def update
      if @pending.update(pending_params)
        redirect_to admin_pending_responses_path, notice: "Borrador actualizado."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def approve
      @pending.update!(status: "approved", approved_by: current_admin_user, acted_at: Time.current)
      redirect_to admin_pending_responses_path, notice: "Aprobado."
    end

    def send_now
      if @pending.update(pending_params.to_h.compact_blank.slice(:draft_body))
        Outbound::SendApprovedJob.perform_later(@pending.id, current_admin_user.id)
        redirect_to admin_pending_responses_path, notice: "Encolado para envío."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def reject
      @pending.update!(status: "rejected", approved_by: current_admin_user, acted_at: Time.current,
                       rejection_reason: params[:rejection_reason])
      redirect_to admin_pending_responses_path, notice: "Rechazado."
    end

    private

    def set_pending
      @pending = PendingResponse.kept.find(params[:id])
    end

    def pending_params
      params.fetch(:pending_response, {}).permit(:draft_body)
    end
  end
end
