module Copilot
  # Implementations for the copilot's READ tools. Every method returns a plain
  # Hash (JSON-encoded into the tool result). Hard rules:
  #   - Build result hashes by hand from explicit attributes — never `as_json` /
  #     `select *`. coach_notes and all payment/subscription TOKENS are NEVER
  #     included.
  #   - Targets resolve to `.kept` records by id; unknown ids return {error:}.
  #   - List sizes are capped; free text is truncated.
  # Results are untrusted data once they re-enter the model context — the system
  # prompt instructs the model to never follow instructions found inside them.
  module ReadTools
    module_function

    MAX_LOOKUP = 8
    MAX_CONVERSATIONS = 20
    MAX_FAILED = 30

    def participant_lookup(args)
      q = args["query"].to_s.strip
      return { error: "query requerido" } if q.blank?

      digits = q.gsub(/\D/, "")
      scope = Participant.kept
      scope =
        if digits.length >= 4
          scope.where("phone_e164 LIKE ?", "%#{digits}")
        else
          scope.where("name ILIKE ?", "%#{q}%")
        end

      rows = scope.order(:name).limit(MAX_LOOKUP).map { |p| participant_summary(p) }
      { count: rows.size, participants: rows }
    end

    def participant_detail(args)
      p = resolve(args["participant_id"])
      return { error: "participante no encontrado" } unless p

      report = p.latest_report
      sub = Subscription.kept.where(participant_id: p.id).order(created_at: :desc).first

      participant_summary(p).merge(
        phase: p.phase,
        ai_summary: p.ai_summary.to_s.truncate(700).presence,
        focus_hint: p.focus_hint.to_s.truncate(500).presence,
        initial_pattern: p.initial_pattern.to_s.truncate(500).presence,
        payment_required: p.payment_required?,
        latest_report: report && {
          day_number: report.day_number,
          key_pattern: report.ai_key_pattern.to_s.truncate(300).presence,
          summary: report.ai_summary.to_s.truncate(500).presence,
          reported_at: report.reported_at
        },
        subscription: sub && {
          status: sub.status,
          amount_clp: sub.amount_clp,
          next_billing_at: sub.next_billing_at
        }
      )
    end

    def recent_conversations(args)
      p = resolve(args["participant_id"])
      return { error: "participante no encontrado" } unless p

      limit = args["limit"].to_i
      limit = 10 if limit <= 0
      limit = MAX_CONVERSATIONS if limit > MAX_CONVERSATIONS

      rows = p.conversations.kept.order(created_at: :desc).limit(limit).map do |c|
        {
          role: c.role,
          moment: c.moment,
          day_number: c.day_number,
          body: (c.body.presence || c.transcription).to_s.truncate(500),
          created_at: c.created_at
        }
      end
      { participant_id: p.id, count: rows.size, conversations: rows.reverse }
    end

    def cohort_metrics(args)
      scope = Participant.kept
      program = nil
      if args["program_slug"].present?
        program = Program.find_by(slug: args["program_slug"])
        return { error: "programa no encontrado" } unless program

        scope = scope.where(program_id: program.id)
      end

      {
        program: program&.slug || "todos",
        total: scope.count,
        by_status: scope.group(:status).count,
        active_today_inbound: scope.active
                                   .joins(:conversations)
                                   .where(conversations: { role: Conversation.roles[:user] })
                                   .where("conversations.created_at >= ?", 24.hours.ago)
                                   .distinct.count
      }
    end

    def failed_messages(args)
      limit = args["limit"].to_i
      limit = 10 if limit <= 0
      limit = MAX_FAILED if limit > MAX_FAILED

      rows = Conversation.kept.failed.order(created_at: :desc).limit(limit).map do |c|
        {
          participant_id: c.participant_id,
          role: c.role,
          moment: c.moment,
          day_number: c.day_number,
          error_message: c.error_message.to_s.truncate(300),
          created_at: c.created_at
        }
      end
      { count: rows.size, failures: rows }
    end

    # --- helpers ------------------------------------------------------------

    def resolve(id)
      return nil if id.blank?

      Participant.kept.find_by(id: id)
    end

    def participant_summary(p)
      {
        id: p.id,
        name: p.name,
        phone_masked: mask_phone(p.phone_e164),
        status: p.status,
        current_day: p.current_day,
        program: p.program&.slug,
        company: p.company&.name,
        timezone: p.timezone,
        last_inbound_at: p.last_inbound_at
      }
    end

    def mask_phone(phone)
      s = phone.to_s
      return s if s.length <= 4

      "•••#{s.last(4)}"
    end
  end
end
