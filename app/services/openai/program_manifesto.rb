module Openai
  module ProgramManifesto
    # coach_name: per-company override; nil falls back to the global coach_name Setting.
    def self.call(program = nil, coach_name: nil)
      base  = program&.manifesto.presence || Setting.fetch("program_manifesto")
      coach = (coach_name.presence || Setting.fetch("coach_name")).to_s.strip
      return base if coach.blank?

      "#{base}\n\nTe llamas #{coach}. Si la persona pregunta tu nombre o cómo dirigirse a ti, responde con naturalidad que eres #{coach}. No inventes apellidos ni cargos."
    end
  end
end
