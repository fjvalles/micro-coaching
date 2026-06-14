module Admin
  class ParticipantsController < BaseController
    before_action :set_participant, only: [
      :show, :edit, :update, :destroy, :enroll, :discard, :undiscard,
      :send_message, :re_enroll, :start_program, :versions,
      :start_intake, :approve_program
    ]

    def index
      # Support search
      query = params[:q]
      scope = Participant.kept

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

      # Filter by company (association)
      if params[:company_id].present?
        scope = params[:company_id] == "none" ? scope.where(company_id: nil) : scope.where(company_id: params[:company_id])
      end

      # Filter by response mode
      if params[:response_mode].present?
        if params[:response_mode] == "blank"
          scope = scope.where(response_mode: [ nil, "" ])
        else
          scope = scope.where(response_mode: params[:response_mode])
        end
      end

      # Filter by enrolled date range
      if params[:enrolled_from].present?
        begin
          scope = scope.where("enrolled_at >= ?", Time.zone.parse(params[:enrolled_from]).beginning_of_day)
        rescue ArgumentError, TypeError
        end
      end
      if params[:enrolled_to].present?
        begin
          scope = scope.where("enrolled_at <= ?", Time.zone.parse(params[:enrolled_to]).end_of_day)
        rescue ArgumentError, TypeError
        end
      end

      if query.present?
        # ransack-like simple search
        scope = scope.where("name ILIKE :q OR phone_e164 ILIKE :q OR email ILIKE :q", q: "%#{query}%")
      end

      @programs = Program.ordered
      @companies = Company.kept.ordered
      @day_contents_lookup = DayContent.all.each_with_object({}) { |dc, h| h[[ dc.program_id, dc.day_number ]] = dc.phase }
      @participants = scope.includes(:program, :company).order(created_at: :desc)
      @message_templates = message_templates
    end

    def show
      @conversations = @participant.conversations.kept.order(created_at: :desc).limit(200)
      @enrollments = @participant.enrollments.includes(:program).order(started_at: :desc).to_a



      @daily_reports = @participant.daily_reports.order(reported_at: :desc).limit(10)
      @message_templates = message_templates
      @dominant_skills = @participant.dominant_skills
    end

    def versions
      scope = @participant.versions

      if params[:date].present?
        date = Date.parse(params[:date]) rescue nil
        if date
          scope = scope.where(created_at: date.beginning_of_day..date.end_of_day)
        end
      end

      if params[:event].present?
        scope = scope.where(event: params[:event])
      end

      if params[:source].present?
        scope = scope.where(source: params[:source])
      end

      if params[:whodunnit].present?
        scope = scope.where("whodunnit ILIKE ?", "%#{params[:whodunnit]}%")
      end

      @page = (params[:page] || 1).to_i
      @per_page = 15
      @total_count = scope.count
      @total_pages = (@total_count.to_f / @per_page).ceil

      @versions = scope.order(created_at: :desc)
                       .limit(@per_page)
                       .offset((@page - 1) * @per_page)

      render layout: false
    end

    def new
      @participant = Participant.new(program_id: params[:program_id], status: :pending, current_day: 0, timezone: (Setting.fetch("default_timezone") || "America/Santiago"))
      @programs = Program.all.order(:name)
      @companies = Company.kept.ordered
    end

    def edit
      @programs = Program.all.order(:name)
      @companies = Company.kept.ordered
    end

    def create
      @participant = Participant.new(participant_params)
      @programs = Program.all.order(:name)
      @companies = Company.kept.ordered
      if @participant.save
        redirect_to admin_participant_path(@participant), notice: "Participante creado exitosamente."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      @programs = Program.all.order(:name)
      @companies = Company.kept.ordered
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

      Participants::Activator.new(@participant).call
      redirect_to admin_participant_path(@participant), notice: "#{@participant.name} inscrito. Bienvenida enviada por WhatsApp."
    end

    # Custom action: advance the participant into the program's next_program
    # (sequential multi-cycle, Nivel 1 → Nivel 2) via Participants::ReEnroller.
    def re_enroll
      target = @participant.program&.next_program
      if target.nil?
        redirect_to admin_participant_path(@participant),
                    alert: "El programa actual no tiene un programa siguiente configurado."
        return
      end

      result = Participants::ReEnroller.new(@participant).call
      if result.ok
        redirect_to admin_participant_path(@participant),
                    notice: "#{@participant.name} pasó a #{target.name}. Bienvenida enviada por WhatsApp."
      else
        redirect_to admin_participant_path(@participant),
                    alert: "No se pudo avanzar al programa siguiente."
      end
    end

    def start_program
      result = Participants::ProgramStarter.new(@participant).call
      if result.ok?
        redirect_to admin_participant_path(@participant),
                    notice: "Programa iniciado. Se encolaron bienvenida y despertar de día 1; el IAReto se enviará después del delay configurado."
      else
        redirect_to admin_participant_path(@participant),
                    alert: start_program_error(result.reason)
      end
    end

    # Custom action: kick off the personalized-program intake questionnaire over
    # WhatsApp (Participants::IntakeStarter). Gated by program_intake_enabled.
    def start_intake
      result = Participants::IntakeStarter.new(@participant).call
      if result.ok?
        redirect_to admin_participant_path(@participant),
                    notice: "Intake iniciado. Se envió la primera pregunta por WhatsApp."
      else
        redirect_to admin_participant_path(@participant),
                    alert: start_intake_error(result.reason)
      end
    end

    # Custom action: approve the AI-generated template awaiting review and start
    # the participant on a live clone (Programs::Approver).
    def approve_program
      template_id = @participant.intake_state["template_program_id"]
      template = template_id && Program.templates.find_by(id: template_id)
      if template.nil?
        redirect_to admin_participant_path(@participant),
                    alert: "No hay un programa generado pendiente de revisión para este participante."
        return
      end

      Programs::Approver.new(participant: @participant, template: template).call
      redirect_to admin_participant_path(@participant),
                  notice: "Programa aprobado y activado. Bienvenida enviada por WhatsApp."
    end

    # Custom action: send a manual message (free text or curated template) now.
    def send_message
      result = Outbound::AdminMessage.new(
        participant: @participant,
        kind: params[:kind],
        body: params[:body],
        template_name: params[:template_name],
        variables: params[:variables]
      ).call

      if result.sent?
        redirect_to admin_participant_path(@participant), notice: "Mensaje enviado a #{@participant.name}."
      else
        redirect_to admin_participant_path(@participant), alert: "No se envió: #{skip_reason_text(result)}"
      end
    end

    # Custom action: broadcast a manual message to selected participants (async fan-out).
    def broadcast
      ids = Array(params[:participant_ids]).reject(&:blank?)
      if ids.empty?
        redirect_to admin_participants_path(request.query_parameters), alert: "Selecciona al menos un participante."
        return
      end

      BroadcastMessageJob.perform_later(
        ids,
        kind: params[:kind],
        body: params[:body],
        template_name: params[:template_name],
        variables: Array(params[:variables]).reject(&:blank?)
      )
      redirect_to admin_participants_path(request.query_parameters),
                  notice: "Envío encolado para #{ids.size} participante(s). Los mensajes de texto fuera de la ventana de 24h se omiten automáticamente."
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

    # WhatsApp templates the admin may send manually: the participant's own
    # program templates (welcome + per-day) plus any extras from the Setting.
    # See Whatsapp::AdminTemplateCatalog.
    def message_templates
      Whatsapp::AdminTemplateCatalog.new(participant: @participant).call
    end

    def skip_reason_text(result)
      case result.skipped_reason
      when :blank_body         then "el mensaje está vacío."
      when :no_template        then "no se eligió una plantilla."
      when :outside_24h_window then "fuera de la ventana de 24h — usa una plantilla aprobada."
      when :send_failed        then "WhatsApp rechazó el envío (#{result.error})."
      else                          "motivo desconocido."
      end
    end

    def start_program_error(reason)
      case reason
      when :no_program             then "Asigna un programa antes de empezarlo."
      when :completed              then "El participante ya completó el programa."
      when :already_past_day_one   then "El participante ya pasó del día 1; usa los envíos manuales del día actual."
      else                              "No se pudo iniciar el programa."
      end
    end

    def start_intake_error(reason)
      case reason
      when :disabled        then "El intake de programa personalizado está desactivado (Setting program_intake_enabled)."
      when :already_active  then "El participante ya está activo o completó el programa; no puede entrar al intake."
      else                       "No se pudo iniciar el intake."
      end
    end

    def participant_params
      params.require(:participant).permit(
        :program_id, :company_id, :name, :phone_e164, :email, :role, :status,
        :current_day, :timezone, :initial_pattern, :energy_map,
        :closing_manifesto, :pending_checkin_at, :response_mode,
        :focus_hint, :coach_notes
      )
    end
  end
end
