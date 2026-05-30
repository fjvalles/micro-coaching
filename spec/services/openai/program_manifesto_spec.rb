require "rails_helper"

RSpec.describe Openai::ProgramManifesto do
  describe ".call" do
    it "returns the global manifesto without coach identity when coach_name is blank" do
      Setting.set("coach_name", "")
      out = described_class.call
      expect(out).to eq(Setting.fetch("program_manifesto"))
      expect(out).not_to include("Te llamas")
    end

    it "appends coach identity when coach_name is set" do
      Setting.set("coach_name", "Diego")
      out = described_class.call
      expect(out).to include("Te llamas Diego")
    end

    it "prefers the program manifesto as the base text" do
      program = create(:program, manifesto: "MANIFIESTO PROPIO DEL PROGRAMA")
      Setting.set("coach_name", "Ana")
      out = described_class.call(program)
      expect(out).to include("MANIFIESTO PROPIO DEL PROGRAMA")
      expect(out).to include("Te llamas Ana")
    end

    it "uses the per-company coach override passed via coach_name:" do
      Setting.set("coach_name", "GlobalBot")
      out = described_class.call(nil, coach_name: "Sofía")
      expect(out).to include("Te llamas Sofía")
      expect(out).not_to include("GlobalBot")
    end

    it "falls back to the global coach_name when the override is nil" do
      Setting.set("coach_name", "GlobalBot")
      out = described_class.call(nil, coach_name: nil)
      expect(out).to include("Te llamas GlobalBot")
    end
  end
end
