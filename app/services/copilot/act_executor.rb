module Copilot
  # Runs an APPROVED act tool through the real service. This is the ONLY place
  # an act tool actually executes — the agent loop never runs them inline; it
  # records a CopilotPendingAction and stops. A superadmin approves, and the
  # controller calls this.
  #
  # Args are re-validated here (defense in depth): targets must resolve to a
  # `.kept` participant, message bodies are bounded, and each action only ever
  # touches a participant that exists in the system. The model's proposed args
  # are never trusted blindly.
  class ActExecutor
    MAX_BODY = 1500

    Result = Struct.new(:ok, :data, keyword_init: true) do
      def ok? = ok
    end

    def initialize(pending_action)
      @action = pending_action
    end

    def call
      return guard("acción no está pendiente") unless @action.pending?

      data = execute
      @action.update!(status: :executed, result: data, executed_at: Time.current)
      post_outcome("✓ #{@action.tool_name}: #{data[:summary] || 'ejecutado'}")
      Result.new(ok: true, data: data)
    rescue StandardError => e
      Sentry.capture_exception(e) if defined?(Sentry)
      @action.update!(status: :failed, result: { error: e.message })
      post_outcome("✗ #{@action.tool_name} falló: #{e.message}")
      Result.new(ok: false, data: { error: e.message })
    end

    private

    def execute
      case @action.tool_name
      when "send_message"         then run_send_message
      when "pause_participant"    then run_pause
      when "reactivate_participant" then run_reactivate
      when "advance_day"          then run_advance_day
      else
        raise "tool de acción desconocido: #{@action.tool_name}"
      end
    end

    def run_send_message
      p = participant!
      body = @action.args["body"].to_s.strip
      raise "body requerido" if body.blank?
      raise "body demasiado largo (máx #{MAX_BODY})" if body.length > MAX_BODY

      result = Outbound::AdminMessage.new(participant: p, kind: "text", body: body).call
      raise "no se envió (#{result.skipped_reason})" unless result.sent?

      { summary: "mensaje enviado a #{p.name}", participant_id: p.id }
    end

    def run_pause
      p = participant!
      return { summary: "#{p.name} ya estaba pausado" } if p.paused?

      p.update!(status: :paused)
      { summary: "#{p.name} pausado", participant_id: p.id }
    end

    def run_reactivate
      p = participant!
      return { summary: "#{p.name} ya estaba activo" } if p.active?

      p.update!(status: :active)
      { summary: "#{p.name} reactivado", participant_id: p.id }
    end

    def run_advance_day
      p = participant!
      outcome = Participants::DayAdvancer.new(participant: p).call
      { summary: "advance_day: #{outcome}", participant_id: p.id, outcome: outcome.to_s }
    end

    # Resolves and validates the target. Never trusts a free-text phone — only a
    # kept participant id the agent obtained from a read tool.
    def participant!
      id = @action.args["participant_id"]
      p = Participant.kept.find_by(id: id)
      raise "participante no encontrado: #{id}" unless p

      p
    end

    def post_outcome(text)
      @action.copilot_session.copilot_messages.create!(role: :assistant, content: text)
    end

    def guard(msg)
      Result.new(ok: false, data: { error: msg })
    end
  end
end
