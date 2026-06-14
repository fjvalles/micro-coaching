module Programs
  # Persists a generated program spec (from Openai::ProgramGenerator) as a reusable
  # TEMPLATE program plus its DayContents, inside a single transaction.
  #
  # Templates are created inactive (active: false) so they never leak into the
  # participant-facing program lists until a human reviews them; the live copy a
  # participant actually runs is produced by Programs::Cloner.
  class Builder
    Result = Struct.new(:program, :error, keyword_init: true) do
      def ok? = program.present? && error.nil?
    end

    def initialize(spec:, company: nil)
      @spec = spec || {}
      @company = company
    end

    def call
      days = Array(@spec["days"])
      return Result.new(error: "spec has no days") if days.empty?

      program = nil
      ActiveRecord::Base.transaction do
        program = Program.create!(
          name: @spec["name"].to_s.truncate(120),
          slug: unique_slug(@spec["name"]),
          manifesto: @spec["manifesto"],
          total_days: @spec["total_days"].to_i,
          company: @company,
          template: true,
          generated: true,
          active: false
        )
        days.each { |day| create_day_content(program, day) }
      end

      Result.new(program: program)
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      Rails.logger.warn("Programs::Builder failed: #{e.message}")
      Result.new(error: e.message)
    end

    private

    def create_day_content(program, day)
      program.day_contents.create!(
        day_number: day["day_number"].to_i,
        phase: day["phase"],
        title: day["title"].to_s.truncate(255).presence || "Día #{day['day_number']}",
        morning_template: day["morning_template"],
        iareto_text: day["iareto_text"],
        checkin_questions: day["checkin_questions"],
        ai_system_prompt: day["ai_system_prompt"],
        active: true
      )
    end

    # Builds a unique, format-valid slug (lowercase, digits, hyphens) from the name.
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
  end
end
