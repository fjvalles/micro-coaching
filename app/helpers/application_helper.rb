module ApplicationHelper
  AUDIT_IGNORED_CHANGE_FIELDS = %w[id created_at updated_at].freeze

  # Translates an ActiveRecord enum value using I18n lookup keys.
  # Falls back to humanizing the value if no translation is found.
  def translate_enum(model, enum_name, value)
    return "" if value.blank?
    I18n.t("activerecord.enums.#{model.model_name.i18n_key}.#{enum_name}.#{value}", default: value.to_s.humanize)
  end

  # Helper to translate participant status enums
  def translate_status(status)
    translate_enum(Participant, :status, status)
  end

  # Helper to translate day content/participant phase enums
  def translate_phase(phase)
    translate_enum(DayContent, :phase, phase)
  end

  # Helper to translate participant response modes
  def translate_response_mode(mode)
    case mode
    when "manual" then "Manual"
    when "suggest" then "Sugerencia IA"
    when "approve" then "Aprobación IA"
    when "auto" then "Automático"
    when "", nil then "Heredar"
    else mode.to_s.humanize
    end
  end

  # Helper to translate conversation moment enums
  def translate_moment(moment)
    translate_enum(Conversation, :moment, moment)
  end

  # Helper to translate conversation role enums
  def translate_role(role)
    translate_enum(Conversation, :role, role)
  end

  def audit_source_badge(source)
    case source
    when "admin" then "badge-info"
    when "ai"    then "badge-warning"
    else              "badge-secondary"
    end
  end

  def audit_event_badge(event)
    case event
    when "create"  then "badge-success"
    when "destroy" then "badge-danger"
    else                "badge-secondary"
    end
  end

  def audit_version_changes(version)
    audit_object_changes(version).each_with_object({}) do |(field, values), filtered|
      next if AUDIT_IGNORED_CHANGE_FIELDS.include?(field.to_s)

      before, after = audit_before_after(values)
      next if audit_normalized_value(before) == audit_normalized_value(after)

      filtered[field] = [ before, after ]
    end
  end

  def translate_audit_field_name(name)
    case name.to_s
    when "name" then "nombre"
    when "status" then "estado"
    when "phone_e164" then "teléfono"
    when "email" then "correo"
    when "current_day", "day_number" then "día"
    when "timezone" then "zona horaria"
    when "company" then "empresa"
    when "role" then "rol"
    when "response_mode" then "modo respuesta"
    when "started_at" then "fecha inicio"
    when "completed_at" then "fecha término"
    when "active" then "activo"
    when "title" then "título"
    when "phase" then "fase"
    when "manifesto" then "manifiesto"
    when "description" then "descripción"
    when "slug" then "slug"
    when "morning_template" then "plantilla mañana"
    when "iareto_text" then "texto iareto"
    when "checkin_questions" then "preguntas checkin"
    when "ai_system_prompt" then "prompt sistema"
    else name.to_s
    end
  end

  def translate_item_type(type)
    case type
    when "Participant" then "Participante"
    when "Program"     then "Programa"
    when "DayContent"  then "Día de Contenido"
    else type.to_s.humanize
    end
  end

  def audit_object_changes(version)
    return {} if version.object_changes.blank?
    return version.object_changes if version.object_changes.is_a?(Hash)

    PaperTrail.serializer.load(version.object_changes)
  rescue StandardError
    begin
      YAML.unsafe_load(version.object_changes) || {}
    rescue StandardError
      {}
    end
  end

  def audit_before_after(values)
    values.is_a?(Array) ? values.first(2) : [ nil, values ]
  end

  def audit_normalized_value(value)
    case value
    when Hash
      value.deep_stringify_keys.transform_values { |nested| audit_normalized_value(nested) }
    when Array
      value.map { |nested| audit_normalized_value(nested) }
    else
      value
    end
  end

  def audit_item_label(version)
    item = version.item
    item ||= begin
      version.reify
    rescue StandardError
      nil
    end

    if item.nil? && version.object_changes.present?
      changes = audit_object_changes(version)
      name = changes["name"]&.last || changes["title"]&.last
      day_number = changes["day_number"]&.last
      if name
        return version.item_type == "DayContent" ? "Día #{day_number} — #{name}" : name
      end
    end

    return "##{version.item_id.to_s.first(8)}" unless item

    case version.item_type
    when "Participant" then item.name
    when "Program"     then item.name
    when "DayContent"  then "Día #{item.day_number} — #{item.title}"
    else item.to_s
    end
  end

  def audit_item_path(version)
    case version.item_type
    when "Participant"
      Participant.kept.exists?(version.item_id) ? admin_participant_path(version.item_id) : "#"
    when "Program"
      Program.exists?(version.item_id) ? admin_program_path(version.item_id) : "#"
    when "DayContent"
      DayContent.exists?(version.item_id) ? admin_day_content_path(version.item_id) : "#"
    else
      "#"
    end
  end

  # Renders markdown text as HTML using Kramdown.
  def render_markdown(text)
    return "" if text.blank?
    require "kramdown" unless defined?(Kramdown)
    Kramdown::Document.new(text, input: "GFM", hard_wrap: false).to_html.html_safe
  end

  # Renders an 'i' icon that displays a tooltip on hover
  def info_tooltip(text)
    content_tag(:span, "i", class: "tooltip-icon", data: { tooltip: text }, title: "")
  end
end
