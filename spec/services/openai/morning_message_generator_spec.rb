require "rails_helper"

RSpec.describe Openai::MorningMessageGenerator do
  let(:participant) { create(:participant, name: "Francisco J") }
  let(:day_content) do
    create(
      :day_content,
      program: participant.program,
      day_number: participant.current_day,
      morning_template: "Observa sin juzgar el impulso de comer algo dulce."
    )
  end

  describe "#user_prompt" do
    subject(:prompt) do
      described_class.new(participant: participant, day_content: day_content).send(:user_prompt)
    end

    it "instructs the model not to duplicate the WhatsApp template greeting" do
      expect(prompt).to include("No incluyas saludo inicial")
      expect(prompt).to include("la plantilla de WhatsApp ya agrega el saludo")
    end
  end

  describe "#call" do
    it "removes duplicated greetings and signatures from the generated body" do
      client = instance_double(Openai::Client)
      allow(client).to receive(:chat).and_return(
        Openai::Client::Result.new(
          content: "Buenos días, Francisco J. Hoy te invito a notar el impulso sin juzgar.\n\n— Impulso Coach",
          tokens_input: 10,
          tokens_output: 5,
          model: "gpt-5-mini",
          latency_ms: 20
        )
      )
      allow(Openai::PromptLogger).to receive(:record)

      result = described_class.new(participant: participant, day_content: day_content, client: client).call

      expect(result.body).to eq("Hoy te invito a notar el impulso sin juzgar.")
    end

    it "cleans the body when parsing catalog JSON output" do
      Setting.set("resource_catalog_enabled", true)
      resource = create(:resource, topics: [ "foco" ], program: participant.program)
      client = instance_double(Openai::Client)
      expect(client).to receive(:chat).with(hash_including(response_format: { type: "json_object" })).and_return(
        Openai::Client::Result.new(
          content: { body: "Hola Francisco J, prueba una pausa breve.\n\nImpulso", resource_id: resource.id }.to_json,
          tokens_input: 10,
          tokens_output: 5,
          model: "gpt-5-mini",
          latency_ms: 20
        )
      )
      allow(Openai::PromptLogger).to receive(:record)

      result = described_class.new(participant: participant, day_content: day_content, client: client).call

      expect(result.body).to eq("prueba una pausa breve.")
      expect(result.resource_id).to eq(resource.id)
      expect(result.resource_catalog).to be true
    end
  end
end
