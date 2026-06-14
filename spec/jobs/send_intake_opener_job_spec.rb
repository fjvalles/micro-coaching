require "rails_helper"

RSpec.describe SendIntakeOpenerJob do
  let(:participant) do
    create(:participant, status: :intake, program: nil, current_day: 0,
                         intake_state: { "step" => 0, "answers" => {}, "awaiting_open" => true })
  end

  before do
    ENV["META_PHONE_NUMBER_ID"] = "1234"
    ENV["META_ACCESS_TOKEN"] = "tok"
    Setting.set("whatsapp_send_enabled", true)
    stub_request(:post, %r{https://graph\.facebook\.com/v\d+\.\d+/1234/messages})
      .to_return(status: 200, body: { messages: [ { id: "wamid.OUT" } ] }.to_json)
  end

  it "sends the configured opener template as the first intake contact" do
    expect {
      described_class.perform_now(participant.id)
    }.to change { participant.conversations.where(moment: :program_intake, role: :assistant).count }.by(1)

    sent = participant.conversations.where(moment: :program_intake, role: :assistant).last
    expect(sent.whatsapp_template_name).to eq("bienvenida_piloto")
  end

  it "is idempotent once the opener has been sent" do
    described_class.perform_now(participant.id)
    expect {
      described_class.perform_now(participant.id)
    }.not_to change(Conversation, :count)
  end

  it "resends when the previous opener was marked failed by Meta" do
    create(:conversation, participant: participant, role: :assistant, moment: :program_intake,
                          sent_at: Time.current, error_message: "Meta reported failed status")

    expect {
      described_class.perform_now(participant.id)
    }.to change { participant.conversations.where(moment: :program_intake, role: :assistant, error_message: nil).count }.by(1)
  end

  it "does nothing for a participant no longer in intake" do
    participant.update!(status: :active, program: create(:program), current_day: 1)
    expect {
      described_class.perform_now(participant.id)
    }.not_to change(Conversation, :count)
  end
end
