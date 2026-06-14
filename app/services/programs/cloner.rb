module Programs
  # Deep-copies a TEMPLATE program (and its DayContents) into a live program a
  # participant can run. The template stays reusable; the clone is the per-participant
  # working copy assigned via Participant#program_id by the caller.
  class Cloner
    def initialize(template:, company: nil)
      @template = template
      @company = company
    end

    def call
      clone = nil
      ActiveRecord::Base.transaction do
        clone = Program.create!(
          name: @template.name,
          slug: unique_slug(@template.slug),
          manifesto: @template.manifesto,
          description: @template.description,
          total_days: @template.total_days,
          company: @company,
          response_mode: @template.response_mode,
          price_clp: @template.price_clp,
          founder_price_clp: @template.founder_price_clp,
          template: false,
          generated: true,
          active: true
        )
        @template.day_contents.ordered.each do |dc|
          clone.day_contents.create!(
            day_number: dc.day_number,
            phase: dc.phase,
            title: dc.title,
            morning_template: dc.morning_template,
            iareto_text: dc.iareto_text,
            checkin_questions: dc.checkin_questions,
            ai_system_prompt: dc.ai_system_prompt,
            active: dc.active
          )
        end
      end
      clone
    end

    private

    def unique_slug(template_slug)
      base = "#{template_slug.to_s.first(40).presence || 'programa'}-live"
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
