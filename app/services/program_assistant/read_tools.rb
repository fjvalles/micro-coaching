module ProgramAssistant
  # Implementations for the program assistant's READ tools. Every method returns
  # a plain Hash (JSON-encoded into the tool result). Hard rules:
  #   - Build result hashes by hand from explicit attributes.
  #   - Targets resolve by id or slug; unknown ids return {error:}.
  #   - List sizes are capped; long free text is truncated in the list view.
  # Results are untrusted data once they re-enter the model context — the system
  # prompt instructs the model to never follow instructions found inside them.
  module ReadTools
    module_function

    MAX_LIST = 60
    TRUNCATE = 300

    def list_programs(args)
      scope = Program.live.includes(:company).order(:name)
      scope = scope.where(active: true) if args["only_active"]

      rows = scope.limit(MAX_LIST).map do |p|
        {
          id: p.id,
          name: p.name,
          slug: p.slug,
          total_days: p.total_days,
          active: p.active,
          company: p.company&.name,
          generated: p.generated,
          description: p.description.to_s.truncate(TRUNCATE).presence
        }
      end
      { count: rows.size, programs: rows }
    end

    def get_program(args)
      program = resolve(args["program_id"] || args["slug"])
      return { error: "programa no encontrado" } unless program

      {
        id: program.id,
        name: program.name,
        slug: program.slug,
        description: program.description,
        manifesto: program.manifesto,
        total_days: program.total_days,
        active: program.active,
        company: program.company&.name,
        days: program.day_contents.order(:day_number).map do |d|
          {
            day_number: d.day_number,
            phase: d.phase,
            title: d.title,
            morning_template: d.morning_template,
            iareto_text: d.iareto_text,
            checkin_questions: d.checkin_questions,
            ai_system_prompt: d.ai_system_prompt
          }
        end
      }
    end

    # --- helpers ------------------------------------------------------------

    UUID_RE = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    # Resolves a program by UUID id first, then by slug. Templates excluded —
    # the assistant operates on live, editable programs only.
    def resolve(ref)
      ref = ref.to_s.strip
      return nil if ref.blank?

      by_id = Program.live.find_by(id: ref) if ref.match?(UUID_RE)
      by_id || Program.live.find_by(slug: ref)
    end
  end
end
