module Admin::OnboardingHelper
  GUIDE_PATH = Rails.root.join("docs/admin-guide.md")

  ONBOARDING_SECTIONS = {
    dashboard_intro: {
      title_fallback: "Introducción al Panel",
      pattern: /Introducción al Panel Nivo/
    },
    dashboard_sections: {
      title_fallback: "Secciones del Sistema",
      pattern: /Secciones del Sistema/
    },
    participant_enrollment: {
      title_fallback: "Inscribir a un Nuevo Participante",
      pattern: /Inscribir a un Nuevo Participante/
    },
    participant_pause: {
      title_fallback: "Pausar o Reactivar a un Participante",
      pattern: /Pausar o Reactivar/
    },
    participant_archive: {
      title_fallback: "Archivar / Eliminar",
      pattern: /Archivar \/ Eliminar/
    },
    program_contents: {
      title_fallback: "Gestionar contenidos de un programa",
      pattern: /Gestionar contenidos/
    },
    participant_chat: {
      title_fallback: "La Ficha del Participante",
      pattern: /La Ficha del Participante/
    },
    settings_live: {
      title_fallback: "Configuración en Vivo",
      pattern: /Monitoreo de Configuración/
    },
    conversations_history: {
      title_fallback: "Historial de Mensajes",
      pattern: /Historial de Mensajes/
    },
    daily_reports_analysis: {
      title_fallback: "Reportes Diarios y Patrones de IA",
      pattern: /Reportes Diarios/
    },
    prompt_templates_management: {
      title_fallback: "Prompts de IA y Plantillas",
      pattern: /Prompts de IA/
    },
    pending_responses_moderation: {
      title_fallback: "Respuestas Pendientes de Moderación",
      pattern: /Respuestas Pendientes/
    },
    admin_users_team: {
      title_fallback: "Administradores y Miembros del Equipo",
      pattern: /Administradores y Miembros/
    },
    audit_logs_history: {
      title_fallback: "Auditoría y Registro de Versiones",
      pattern: /Auditoría y Registro/
    }
  }.freeze

  def render_layout_onboarding
    keys = Array(onboarding_keys_for(controller_name, action_name))
    return nil if keys.empty?

    htmls = keys.map { |key| render_onboarding(key) }.compact
    safe_join(htmls)
  end

  def onboarding_keys_for(controller, action)
    case controller
    when "dashboard"
      [ :dashboard_intro, :dashboard_sections ]
    when "participants"
      if action == "show"
        [ :participant_chat, :participant_pause ]
      elsif action == "new" || action == "create"
        [ :participant_enrollment ]
      else
        [ :participant_enrollment, :participant_archive ]
      end
    when "day_contents", "programs"
      [ :program_contents ]
    when "settings"
      [ :settings_live ]
    when "conversations"
      [ :conversations_history ]
    when "daily_reports"
      [ :daily_reports_analysis ]
    when "prompt_templates"
      [ :prompt_templates_management ]
    when "pending_responses"
      [ :pending_responses_moderation ]
    when "admin_users"
      [ :admin_users_team ]
    when "audit_logs"
      [ :audit_logs_history ]
    else
      []
    end
  end

  def render_onboarding(key)
    section_meta = ONBOARDING_SECTIONS[key.to_sym]
    return nil unless section_meta

    parsed = parse_guide_section(section_meta[:pattern])
    return nil unless parsed

    title = parsed[:title] || section_meta[:title_fallback]
    body_html = render_markdown(parsed[:body])

    render partial: "admin/shared/onboarding_card", locals: {
      key: key.to_s,
      title: title,
      body_html: body_html
    }
  end

  def parse_guide_section(pattern)
    return nil unless File.exist?(GUIDE_PATH)

    content = File.read(GUIDE_PATH, encoding: "UTF-8")
    lines = content.lines
    section_lines = []
    in_section = false
    current_level = 0

    lines.each do |line|
      if line.start_with?("#")
        header_level = line.match(/^#+/)[0].length
        if in_section
          if header_level <= current_level
            break
          else
            section_lines << line
          end
        elsif line =~ pattern
          in_section = true
          current_level = header_level
          section_lines << line
        end
      elsif in_section
        section_lines << line
      end
    end

    return nil if section_lines.empty?

    # Extract title from the first header line
    first_line = section_lines.shift
    title = nil
    if first_line&.start_with?("#")
      title = first_line.sub(/^#+\s*/, "").sub(/^\d+(\.\d+)*\s*/, "").strip
    end

    body = section_lines.join.strip
    { title: title, body: body }
  end
end
