module Admin
  class ParticipantsController < BaseController
    before_action :set_participant, only: [ :show, :edit, :update, :destroy, :enroll, :discard, :undiscard ]

    def index
      # Support search
      query = params[:q]
      scope = Participant.all # Include discarded ones in search/admin view if needed, or filter by tab

      # Soft-delete scopes (kept vs discarded)
      status_filter = params[:status] || "kept"

      if status_filter == "discarded"
        scope = scope.discarded
      else
        scope = scope.kept
      end

      # Filter by status enum
      if params[:status_enum].present?
        scope = scope.where(status: params[:status_enum])
      end

      # Filter by program
      if params[:program_id].present?
        if params[:program_id] == "none"
          scope = scope.where(program_id: nil)
        else
          scope = scope.where(program_id: params[:program_id])
        end
      end

      # Filter by current day
      if params[:current_day].present?
        scope = scope.where(current_day: params[:current_day])
      end

      # Filter by phase (joined through day_contents on matching program + day)
      if params[:phase].present? && DayContent.phases.key?(params[:phase])
        scope = scope
          .joins("INNER JOIN day_contents ON day_contents.program_id = participants.program_id AND day_contents.day_number = participants.current_day")
          .where(day_contents: { phase: DayContent.phases[params[:phase]] })
      end

      # Filter by pending check-in (awaiting response)
      if params[:pending_checkin].present?
        scope = params[:pending_checkin] == "yes" ? scope.where.not(pending_checkin_at: nil) : scope.where(pending_checkin_at: nil)
      end

      # Filter by timezone
      if params[:timezone].present?
        scope = scope.where(timezone: params[:timezone])
      end

      # Filter by enrolled date preset (today/7d/30d/never)
      if params[:enrolled_preset].present?
        case params[:enrolled_preset]
        when "today"   then scope = scope.where(enrolled_at: Time.current.beginning_of_day..)
        when "last_7"  then scope = scope.where(enrolled_at: 7.days.ago..)
        when "last_30" then scope = scope.where(enrolled_at: 30.days.ago..)
        when "never"   then scope = scope.where(enrolled_at: nil)
        end
      end

      if query.present?
        # ransack-like simple search
        scope = scope.where("name ILIKE :q OR phone_e164 ILIKE :q OR email ILIKE :q", q: "%#{query}%")
      end

      @programs = Program.ordered
      @timezones = Participant.kept.distinct.pluck(:timezone).compact.sort
      @participants = scope.includes(:program).order(created_at: :desc)
    end

    def show
      @conversations = @participant.conversations.kept.order(created_at: :desc).limit(50)
      @daily_reports = @participant.daily_reports.order(reported_at: :desc).limit(10)
    end

    def new
      @participant = Participant.new(program_id: params[:program_id], status: :pending, current_day: 0, timezone: "America/Mexico_City")
      @programs = Program.all.order(:name)
    end

    def edit
      @programs = Program.all.order(:name)
    end

    def create
      @participant = Participant.new(participant_params)
      @programs = Program.all.order(:name)
      if @participant.save
        redirect_to admin_participant_path(@participant), notice: "Participante creado exitosamente."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      @programs = Program.all.order(:name)
      if @participant.update(participant_params)
        redirect_to admin_participant_path(@participant), notice: "Participante actualizado exitosamente."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # Hard delete (or soft delete)
      # Since we have soft delete via discard, let's make destroy do a soft-delete (discard)
      # and have a separate action if needed. Or just call discard.
      @participant.discard
      redirect_to admin_participants_path, notice: "Participante archivado (soft-deleted)."
    end

    # Custom action: enroll
    def enroll
      if @participant.active?
        redirect_to admin_participant_path(@participant), alert: "#{@participant.name} ya está activo en el programa."
        return
      end

      @participant.update!(
        status: :active,
        current_day: 1,
        enrolled_at: Time.current,
        started_at: Time.current
      )
      SendWelcomeJob.perform_later(@participant.id)
      redirect_to admin_participant_path(@participant), notice: "#{@participant.name} inscrito. Bienvenida enviada por WhatsApp."
    end

    # Custom action: discard (soft-delete)
    def discard
      @participant.discard
      redirect_to admin_participant_path(@participant), notice: "Participante archivado."
    end

    # Custom action: undiscard (restore)
    def undiscard
      @participant.undiscard
      redirect_to admin_participant_path(@participant), notice: "Participante restaurado."
    end

    private

    def set_participant
      @participant = Participant.find(params[:id])
    end

    def participant_params
      params.require(:participant).permit(
        :program_id, :name, :phone_e164, :email, :company, :role, :status,
        :current_day, :timezone, :initial_pattern, :energy_map,
        :closing_manifesto, :pending_checkin_at
      )
    end
  end
end
