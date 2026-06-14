module Whatsapp
  # Builds the list of approved WhatsApp templates an admin can manually send to
  # a participant, derived from the program's own DayContents (welcome + per-day
  # despertar / iareto / checkin) plus any extra templates curated in the
  # admin_message_templates Setting. The per-day names mirror exactly what the
  # cron jobs send (SendWelcomeJob, MorningWakeForParticipantJob, SendIaretoJob,
  # CheckinForParticipantJob), so the dropdown only ever lists templates that
  # actually exist in Meta for this program.
  #
  # Variables are prefilled wherever the content is static (nombre, texto IARETO,
  # preguntas del check-in) so the admin rarely has to type anything. The morning
  # "mensaje" is AI-generated, so it is left blank for the admin to fill.
  #
  # Returns an Array of Hashes shaped for the _message_composer partial:
  #   { "name" => "iareto_dia_03", "label" => "Día 3 · IARETO",
  #     "variables" => [ { "label" => "Nombre", "default" => "Ana" },
  #                      { "label" => "Texto IARETO", "default" => "…" } ] }
  #
  # When no participant is given (e.g. the broadcast composer fans out to many),
  # only the welcome and curated Setting templates are listed — per-day templates
  # carry participant/program-specific content that can't be shared across a
  # broadcast, so they're omitted.
  class AdminTemplateCatalog
    def initialize(participant: nil)
      @participant = participant
    end

    def call
      # Program templates take precedence over custom Setting entries of the
      # same name (uniq keeps the first occurrence).
      ([ welcome ] + day_templates + custom).compact.uniq { |t| t["name"] }
    end

    private

    attr_reader :participant

    def welcome
      template("bienvenida_piloto", "Bienvenida", [ nombre ])
    end

    def day_templates
      program = participant&.program
      return [] unless program

      program.day_contents.active.ordered.flat_map do |dc|
        [ despertar(dc), iareto(dc), checkin(dc) ].compact
      end
    end

    def despertar(dc)
      name = dc.template_name_whatsapp.presence || format("despertar_dia_%02d", dc.day_number)
      template(name, "Día #{dc.day_number} · Despertar", [ nombre, var("Mensaje", "") ])
    end

    def iareto(dc)
      return nil if dc.iareto_text.blank?

      template(format("iareto_dia_%02d", dc.day_number),
               "Día #{dc.day_number} · IARETO",
               [ nombre, var("Texto IARETO", template_body(dc.iareto_text)) ])
    end

    def checkin(dc)
      return nil if dc.checkin_questions.blank?

      # Mirror CheckinForParticipantJob: first 3 non-blank question lines.
      questions = template_body(dc.checkin_questions).split("\n").reject(&:blank?).first(3).join("\n\n")
      template(format("checkin_dia_%02d", dc.day_number),
               "Día #{dc.day_number} · Check-in",
               [ nombre, var("Preguntas", questions) ])
    end

    # Extra hand-curated templates from the Setting (string-array vars supported
    # for backward compatibility); appended after the program templates.
    def custom
      list = Setting.fetch("admin_message_templates")
      return [] unless list.is_a?(Array)

      list.filter_map do |t|
        next unless t.is_a?(Hash) && t["name"].present?

        vars = Array(t["variables"]).map { |v| v.is_a?(Hash) ? v : var(v.to_s, "") }
        template(t["name"], t["label"].presence || t["name"], vars)
      end
    end

    def nombre
      var("Nombre", participant&.name)
    end

    def template_body(body)
      Whatsapp::TemplateBodySanitizer.call(body, participant_name: participant&.name)
    end

    def var(label, default)
      { "label" => label, "default" => default.to_s }
    end

    def template(name, label, variables)
      { "name" => name, "label" => label, "variables" => variables }
    end
  end
end
