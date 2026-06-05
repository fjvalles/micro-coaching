module Openai
  # Builds the deterministic, stable skill catalog block injected as the static
  # prefix of the SkillTagger system prompt. Kept large and order-stable on
  # purpose so OpenAI prompt caching kicks in across participants (same pattern
  # as Openai::ProgramManifesto). Each line gives the classifier the slug, name,
  # and the "señales" cues — the labeled signals it matches the message against.
  module SkillCatalog
    module_function

    def call(skills = Skill.active.ordered)
      skills.map { |s| line_for(s) }.join("\n")
    end

    def line_for(skill)
      signals = Array(skill.signals).first(5).map { |x| x.to_s.gsub(/\s+/, " ").strip }.reject(&:blank?)
      base = "- #{skill.slug}: #{skill.name}"
      signals.any? ? "#{base} — señales: #{signals.join('; ')}" : base
    end
  end
end
