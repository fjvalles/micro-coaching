module Openai
  module ProgramManifesto
    def self.call(program = nil)
      program&.manifesto.presence || Setting.fetch("program_manifesto")
    end
  end
end
