module Admin
  class CoachSessionsController < BaseController
    before_action :set_coach_session, only: %i[show edit update destroy]

    def index
      scope = CoachSession.kept.includes(:participant, :coach)
      scope = scope.where(status: params[:status]) if params[:status].present? && CoachSession.statuses.key?(params[:status])
      scope = scope.where(participant_id: params[:participant_id]) if params[:participant_id].present?

      @upcoming = scope.upcoming
      @past     = scope.past.limit(50)
    end

    def show; end

    def new
      @coach_session = CoachSession.new(
        participant_id: params[:participant_id],
        duration_minutes: 30,
        status: :confirmed
      )
      load_form_collections
    end

    def edit
      load_form_collections
    end

    def create
      @coach_session = CoachSession.new(coach_session_params)
      if @coach_session.save
        redirect_to admin_coach_session_path(@coach_session), notice: "Sesión agendada."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @coach_session.update(coach_session_params)
        redirect_to admin_coach_session_path(@coach_session), notice: "Sesión actualizada."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @coach_session.discard
      redirect_to admin_coach_sessions_path, notice: "Sesión archivada."
    end

    private

    def set_coach_session
      @coach_session = CoachSession.kept.find(params[:id])
    end

    def load_form_collections
      @participants = Participant.kept.order(:name)
      @coaches      = AdminUser.order(:name)
    end

    def coach_session_params
      params.require(:coach_session).permit(
        :participant_id, :admin_user_id, :status, :scheduled_at,
        :duration_minutes, :meeting_url, :notes
      )
    end
  end
end
