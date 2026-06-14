require "rails_helper"

RSpec.describe SendNivel2OfferJob do
  let(:participant) { create(:participant, status: :completed, completed_at: Time.current, current_day: 15) }

  before do
    Setting.set("nivel2_offer_enabled", true)
    Setting.set("nivel2_offer_window_hours", 48)
    allow(Openai::Nivel2OfferGenerator).to receive(:new).and_return(
      instance_double(Openai::Nivel2OfferGenerator,
                      call: Openai::Nivel2OfferGenerator::Result.new(
                        body: "Lo que construiste", prompt_used: "{}",
                        tokens_input: 1, tokens_output: 1, model: "gpt-4.1-mini"
                      ))
    )
    allow(Whatsapp::Client).to receive(:new).and_return(
      instance_double(Whatsapp::Client, send_text: double(success?: true, wamid: "wamid.x", error: nil))
    )
  end

  it "sends the offer, appends the CTA terms, and stamps the founder window" do
    expect {
      described_class.perform_now(participant.id)
    }.to change { participant.conversations.where(moment: :nivel2_offer).count }.by(1)

    convo = participant.conversations.find_by(moment: :nivel2_offer)
    expect(convo.body).to include("Lo que construiste")
    expect(convo.body).to include("48") # CTA interpolates window hours
    expect(participant.reload.nivel2_offer_sent_at).to be_present
  end

  it "is a no-op when the kill-switch is off" do
    Setting.set("nivel2_offer_enabled", false)
    expect(Whatsapp::Client).not_to receive(:new)
    described_class.perform_now(participant.id)
    expect(participant.reload.nivel2_offer_sent_at).to be_nil
  end

  it "does not offer to a non-completed participant" do
    participant.update!(status: :active, current_day: 5)
    expect(Whatsapp::Client).not_to receive(:new)
    described_class.perform_now(participant.id)
  end

  it "is idempotent once an offer has been sent" do
    create(:conversation, participant: participant, role: :assistant, moment: :nivel2_offer, sent_at: Time.current)
    expect(Openai::Nivel2OfferGenerator).not_to receive(:new)
    expect {
      described_class.perform_now(participant.id)
    }.not_to change { participant.conversations.where(moment: :nivel2_offer).count }
  end
end
