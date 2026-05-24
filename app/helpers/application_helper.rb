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

  # Helper to translate conversation moment enums
  def translate_moment(moment)
    translate_enum(Conversation, :moment, moment)
  end

  # Helper to translate conversation role enums
  def translate_role(role)
    translate_enum(Conversation, :role, role)
  end
end
