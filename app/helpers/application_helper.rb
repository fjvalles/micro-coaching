module ApplicationHelper
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

  def audit_item_label(version)
    item = version.item
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
    when "Participant" then admin_participant_path(version.item_id)
    when "Program"     then admin_program_path(version.item_id)
    when "DayContent"  then admin_day_content_path(version.item_id)
    else "#"
    end
  end

  # Renders markdown text as HTML using Kramdown.
  def render_markdown(text)
    return "" if text.blank?
    require "kramdown" unless defined?(Kramdown)
    Kramdown::Document.new(text, input: "GFM", hard_wrap: false).to_html.html_safe
  end
end
