module Skills
  # Builds a short, naturally-phrased coaching nudge for the participant's most
  # frequently detected skill in a recent window, injected into the generative
  # system prompts (free reply + morning message) so the AI coaches concretely on
  # what the person actually needs instead of generically. Returns nil when the
  # feature is off, there are no recent detections, or the skill is unknown.
  module CoachingHint
    module_function

    DEFAULT_WINDOW = 14.days

    def for(participant, since: DEFAULT_WINDOW.ago)
      return nil unless Setting.fetch("skill_coaching_injection_enabled")

      skill = top_skill(participant, since)
      return nil unless skill

      build(skill)
    end

    def top_skill(participant, since)
      skill_id = SkillDetection
                 .where(participant_id: participant.id).since(since)
                 .group(:skill_id).order(Arel.sql("COUNT(*) DESC")).limit(1)
                 .pluck(:skill_id).first
      skill_id && Skill.active.find_by(id: skill_id)
    end

    def build(skill)
      practice = Array(skill.practices).first
      gesture  = Array(skill.gestures).first
      exercise = Array(skill.exercises).first

      parts = [ "Habilidad a reforzar en esta persona: #{skill.name}." ]
      parts << skill.definition.to_s.truncate(220) if skill.definition.present?
      parts << "Práctica útil: #{practice}" if practice.present?
      parts << "Gesto concreto: #{gesture}" if gesture.present?
      parts << "Posible micro-ejercicio: #{exercise}" if exercise.present?
      parts << "Cuando sea natural, ayúdale a desarrollarla. No lo menciones como " \
               "\"habilidad detectada\" ni suenes a manual: intégralo con naturalidad."
      parts.join("\n")
    end
  end
end
