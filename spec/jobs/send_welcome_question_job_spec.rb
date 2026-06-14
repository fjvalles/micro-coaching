require "rails_helper"

RSpec.describe SendWelcomeQuestionJob, type: :job do
  before do
    ENV["META_PHONE_NUMBER_ID"] = "1234"
    ENV["META_ACCESS_TOKEN"] = "test_token"
    Setting.set("meta_api_version", "v21.0")
    Setting.set("whatsapp_send_enabled", true)
  end

  let(:participant) { create(:participant, phone_e164: "+56912345678") }
  let(:url) { "https://graph.facebook.com/v21.0/1234/messages" }

  it "sends the initial pattern question when it is still needed" do
    stub_request(:post, url)
      .to_return(status: 200, body: { messages: [ { id: "wamid.OK" } ] }.to_json,
                 headers: { "Content-Type" => "application/json" })

    expect {
      described_class.perform_now(participant.id)
    }.to change { participant.conversations.kept.where(moment: :welcome, role: :assistant).count }.by(1)

    conversation = participant.conversations.kept.order(:created_at).last
    expect(conversation.body).to eq(described_class::QUESTION)
    expect(conversation.sent_at).to be_present
  end

  it "does not send when the participant already answered the initial pattern" do
    participant.update!(initial_pattern: "Me quedo en lo cómodo")

    expect {
      described_class.perform_now(participant.id)
    }.not_to change(Conversation, :count)

    expect(a_request(:post, url)).not_to have_been_made
  end

  it "does not send when a welcome user answer already exists" do
    create(:conversation, participant: participant, moment: :welcome, role: :user, body: "Mi patrón")

    expect {
      described_class.perform_now(participant.id)
    }.not_to change(Conversation, :count)

    expect(a_request(:post, url)).not_to have_been_made
  end

  it "does not send a duplicate welcome question" do
    create(:conversation, participant: participant, moment: :welcome, role: :assistant,
                          day_number: 0, body: described_class::QUESTION, sent_at: 5.minutes.ago)

    expect {
      described_class.perform_now(participant.id)
    }.not_to change(Conversation, :count)

    expect(a_request(:post, url)).not_to have_been_made
  end
end
