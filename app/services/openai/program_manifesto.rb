module Openai
  def self.program_manifesto(program = nil)
    program&.manifesto.presence || Setting.fetch("program_manifesto")
  end
end
