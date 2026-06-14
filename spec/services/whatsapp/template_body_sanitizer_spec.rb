require "rails_helper"

RSpec.describe Whatsapp::TemplateBodySanitizer do
  it "removes a duplicated greeting with the participant name" do
    result = described_class.call("Buenos días, Francisco J. Observa el impulso sin juzgar.", participant_name: "Francisco J")

    expect(result).to eq("Observa el impulso sin juzgar.")
  end

  it "removes a leading participant name without a greeting" do
    result = described_class.call("Francisco J, registra una pausa breve.", participant_name: "Francisco J")

    expect(result).to eq("registra una pausa breve.")
  end

  it "removes a trailing Impulso signature" do
    result = described_class.call("Prueba una pausa breve.\n\n— Impulso Coach", participant_name: "Francisco J")

    expect(result).to eq("Prueba una pausa breve.")
  end

  it "keeps the original body when cleanup would blank it" do
    result = described_class.call("Hola Francisco J", participant_name: "Francisco J")

    expect(result).to eq("Hola Francisco J")
  end
end
