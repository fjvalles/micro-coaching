require "rails_helper"

RSpec.describe ProgramGenerationJob do
  let(:participant) do
    create(:participant, status: :intake, program: nil, current_day: 0,
                         intake_state: { "step" => 7, "answers" => { "pattern" => "reviso el celular" } })
  end

  def valid_spec_json(total: 6)
    days = (1..total).map do |d|
      phase = d == 1 ? "see" : (d == total ? "anchor" : "choose")
      { day_number: d, phase: phase, title: "Día #{d}", morning_template: "Buen día",
        iareto_text: "Reto", checkin_questions: "¿Cómo te fue?", ai_system_prompt: "Refuerza" }
    end
    { name: "Reset de mañanas", manifesto: "Tus mañanas.", total_days: total, days: days }.to_json
  end

  def stub_openai(content)
    allow_any_instance_of(Openai::Client).to receive(:chat).and_return(
      Openai::Client::Result.new(content: content, tokens_input: 100, tokens_output: 500, model: "gpt-5-mini", latency_ms: 300)
    )
  end

  before { Setting.fetch("program_intake_enabled") } # warm schema

  context "when the kill-switch is off" do
    it "does nothing" do
      allow(Setting).to receive(:fetch).and_call_original
      allow(Setting).to receive(:fetch).with("program_intake_enabled").and_return(false)
      expect_any_instance_of(Openai::Client).not_to receive(:chat)

      expect { described_class.perform_now(participant.id) }.not_to change(Program, :count)
    end
  end

  context "when enabled and review is required (default)" do
    before do
      allow(Setting).to receive(:fetch).and_call_original
      allow(Setting).to receive(:fetch).with("program_intake_enabled").and_return(true)
      allow(Setting).to receive(:fetch).with("program_intake_review_required").and_return(true)
      stub_openai(valid_spec_json)
    end

    it "builds an inactive template and flags the participant for review without activating" do
      expect { described_class.perform_now(participant.id) }.to change(Program.templates, :count).by(1)

      participant.reload
      expect(participant).to be_intake
      expect(participant.intake_awaiting_review?).to be(true)
      expect(participant.intake_state["template_program_id"]).to be_present
      expect(participant.program).to be_nil
      expect(Program.where(generated: true, template: false).count).to eq(0)
    end

    it "does not re-generate when already awaiting review" do
      described_class.perform_now(participant.id)
      expect { described_class.perform_now(participant.id) }.not_to change(Program, :count)
    end
  end

  context "when enabled and review is not required" do
    before do
      allow(Setting).to receive(:fetch).and_call_original
      allow(Setting).to receive(:fetch).with("program_intake_enabled").and_return(true)
      allow(Setting).to receive(:fetch).with("program_intake_review_required").and_return(false)
      stub_openai(valid_spec_json)
    end

    it "clones the template into a live program and activates the participant" do
      described_class.perform_now(participant.id)

      participant.reload
      expect(participant).to be_active
      expect(participant.program).to be_present
      expect(participant.program.template).to be(false)
      expect(participant.current_day).to eq(1)
    end
  end

  context "when generation fails" do
    before do
      allow(Setting).to receive(:fetch).and_call_original
      allow(Setting).to receive(:fetch).with("program_intake_enabled").and_return(true)
      stub_openai("not json")
    end

    it "sends the failure message and leaves the participant in intake" do
      expect_any_instance_of(Outbound::Dispatcher).to receive(:send_text)
      described_class.perform_now(participant.id)
      expect(participant.reload).to be_intake
    end
  end
end
