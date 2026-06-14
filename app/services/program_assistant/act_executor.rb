module ProgramAssistant
  # Runs an APPROVED act tool through the real persistence layer. This is the
  # ONLY place a program write happens — the agent loop never runs act tools
  # inline; it records a ProgramAssistantPendingAction and stops. An admin
  # approves, and the controller calls this.
  #
  # Args are re-validated here (defense in depth): day_numbers must be positive
  # and unique, phases must be valid, and the whole write runs in a transaction
  # so a malformed proposal can't leave a half-built program behind.
  class ActExecutor
    PHASES = %w[see choose anchor].freeze
    MAX_DAYS = 60

    Result = Struct.new(:ok, :data, keyword_init: true) do
      def ok? = ok
    end

    def initialize(pending_action)
      @action = pending_action
      @args = pending_action.args || {}
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
      when "create_program" then run_create
      when "update_program" then run_update
      else
        raise "tool de acción desconocido: #{@action.tool_name}"
      end
    end

    def run_create
      name = @args["name"].to_s.strip
      raise "name requerido" if name.blank?

      days = validated_days(@args["days"])
      raise "se requiere al menos un día" if days.empty?

      total = @args["total_days"].to_i
      total = days.size if total <= 0

      program = nil
      ActiveRecord::Base.transaction do
        program = Program.create!(
          name: name.truncate(120),
          slug: unique_slug(name),
          description: @args["description"].presence,
          manifesto: @args["manifesto"].presence,
          total_days: total,
          template: false,
          generated: true,
          active: false
        )
        days.each { |d| upsert_day(program, d) }
      end

      {
        summary: "programa \"#{program.name}\" creado con #{days.size} día(s)",
        program_id: program.id,
        slug: program.slug
      }
    end

    def run_update
      program = ReadTools.resolve(@args["program_id"] || @args["slug"])
      raise "programa no encontrado" unless program

      days = validated_days(@args["days"])

      ActiveRecord::Base.transaction do
        attrs = {}
        attrs[:name] = @args["name"].to_s.truncate(120) if @args["name"].present?
        attrs[:description] = @args["description"] if @args.key?("description")
        attrs[:manifesto] = @args["manifesto"] if @args.key?("manifesto")
        attrs[:total_days] = @args["total_days"].to_i if @args["total_days"].to_i.positive?
        program.update!(attrs) if attrs.any?

        days.each { |d| upsert_day(program, d) }
      end

      {
        summary: "programa \"#{program.name}\" actualizado (#{days.size} día(s) modificados)",
        program_id: program.id,
        slug: program.slug
      }
    end

    # Inserts or updates a DayContent by day_number (idempotent upsert).
    def upsert_day(program, day)
      record = program.day_contents.find_or_initialize_by(day_number: day["day_number"].to_i)
      record.phase = day["phase"]
      record.title = day["title"].to_s.truncate(255).presence || "Día #{day['day_number']}"
      record.morning_template = day["morning_template"] if day.key?("morning_template")
      record.iareto_text = day["iareto_text"] if day.key?("iareto_text")
      record.checkin_questions = day["checkin_questions"] if day.key?("checkin_questions")
      record.ai_system_prompt = day["ai_system_prompt"] if day.key?("ai_system_prompt")
      record.active = true
      record.save!
    end

    # Structural validation of the proposed days. Never trusts the model blindly.
    def validated_days(raw)
      days = Array(raw)
      raise "demasiados días (máx #{MAX_DAYS})" if days.size > MAX_DAYS

      seen = {}
      days.each do |d|
        n = d["day_number"].to_i
        raise "day_number inválido: #{d['day_number'].inspect}" unless n.positive?
        raise "day_number duplicado: #{n}" if seen[n]
        raise "phase inválida: #{d['phase'].inspect}" unless PHASES.include?(d["phase"].to_s)

        seen[n] = true
      end
      days
    end

    # Builds a unique, format-valid slug (lowercase, digits, hyphens) from name.
    def unique_slug(name)
      base = name.to_s.parameterize.presence || "programa"
      base = base.first(50)
      candidate = base
      n = 1
      while Program.exists?(slug: candidate)
        n += 1
        candidate = "#{base}-#{n}"
      end
      candidate
    end

    def post_outcome(text)
      @action.program_assistant_session.program_assistant_messages.create!(role: :assistant, content: text)
    end

    def guard(msg)
      Result.new(ok: false, data: { error: msg })
    end
  end
end
