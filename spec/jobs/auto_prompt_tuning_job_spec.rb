require "rails_helper"

RSpec.describe AutoPromptTuningJob, type: :job do
  let(:participant) { create(:participant) }

  before do
    Setting.set("auto_prompt_tuning_enabled", true)
    Setting.set("auto_prompt_tuning_mode", "observe")
    Setting.set("auto_tuning_score_threshold", 95)
    Setting.set("auto_tuning_sample_size", 30)
    Setting.set("free_chat_style_guardrails", Setting::DEFAULT_FREE_CHAT_STYLE_GUARDRAILS)
  end

  it "is a no-op when disabled" do
    Setting.set("auto_prompt_tuning_enabled", false)

    expect { described_class.new.perform(Time.zone.parse("2026-06-15 04:00")) }
      .not_to change(PromptTuningRun, :count)
  end

  it "records one observed run per weekly window" do
    now = Time.zone.parse("2026-06-15 04:00")

    expect {
      described_class.new.perform(now)
      described_class.new.perform(now)
    }.to change(PromptTuningRun, :count).by(1)

    expect(PromptTuningRun.last.status).to eq("observed")
    expect(ConversationQualityScore.count).to eq(1)
  end

  it "creates a pending proposal in propose mode when score is below threshold" do
    Setting.set("auto_prompt_tuning_mode", "propose")
    now = Time.zone.parse("2026-06-15 04:00")
    create(:conversation, participant: participant, role: :user, moment: :free_user, body: "No sé", created_at: Time.zone.parse("2026-06-10 10:00"))
    create(:conversation, participant: participant, role: :assistant, moment: :free_assistant, body: "Gracias por decirlo. ¿Qué notas en el cuerpo y qué harás?", created_at: Time.zone.parse("2026-06-10 10:01"))

    proposal = Openai::GuardrailProposer::Result.new(
      findings: { "weaknesses" => [ "preguntas compuestas" ] },
      proposed_guardrails: "#{Setting::DEFAULT_FREE_CHAT_STYLE_GUARDRAILS}\n- Haz una sola pregunta y respeta la autonomía.",
      rationale: "Reduce fricción.",
      change_kind: "append_bullet",
      tokens_input: 1,
      tokens_output: 1,
      model: "gpt-5-mini"
    )
    allow_any_instance_of(Openai::GuardrailProposer).to receive(:call).and_return(proposal)

    expect {
      described_class.new.perform(now)
    }.to have_enqueued_mail(PromptTuningMailer, :proposal)

    run = PromptTuningRun.last
    expect(run.status).to eq("proposed")
    expect(run.proposed_guardrails).to include("Haz una sola pregunta")
  end
end
