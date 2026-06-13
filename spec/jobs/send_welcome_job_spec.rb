require "rails_helper"

RSpec.describe SendWelcomeJob, type: :job do
  before do
    ENV["META_PHONE_NUMBER_ID"] = "1234"
    ENV["META_ACCESS_TOKEN"] = "test_token"
    ENV["META_API_VERSION"] = "v21.0"
    Rails.cache.clear
    Setting.set("meta_api_version", "v21.0")
    Setting.set("whatsapp_send_enabled", true)
  end

  let(:participant) { create(:participant, name: "Carlos E2E Test", phone_e164: "+56912345678") }
  let(:url) { "https://graph.facebook.com/v21.0/1234/messages" }

  it "enqueues the welcome question when the welcome template is sent" do
    stub_request(:post, url)
      .to_return(status: 200, body: { messages: [ { id: "wamid.OK" } ] }.to_json,
                 headers: { "Content-Type" => "application/json" })

    expect {
      described_class.perform_now(participant.id)
    }.to have_enqueued_job(SendWelcomeQuestionJob).with(participant.id)

    conversation = participant.conversations.kept.find_by(moment: :welcome, whatsapp_template_name: "bienvenida_piloto")
    expect(conversation).to be_present
    expect(conversation.sent_at).to be_present
    expect(conversation.error_message).to be_nil
  end

  it "does not enqueue the welcome question when Meta rejects the template" do
    stub_request(:post, url)
      .to_return(
        status: 400,
        body: {
          error: {
            message: "Recipient phone number not in allowed list",
            code: 131030
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    expect {
      described_class.perform_now(participant.id)
    }.not_to have_enqueued_job(SendWelcomeQuestionJob)

    conversation = participant.conversations.kept.find_by(moment: :welcome, whatsapp_template_name: "bienvenida_piloto")
    expect(conversation).to be_present
    expect(conversation.sent_at).to be_nil
    expect(conversation.error_message).to include("allowed list")
  end

  it "does not send a duplicate welcome when one was already sent" do
    create(:conversation, participant: participant, moment: :welcome, day_number: 0, sent_at: 1.hour.ago)

    expect {
      described_class.perform_now(participant.id)
    }.not_to have_enqueued_job(SendWelcomeQuestionJob)

    expect(a_request(:post, url)).not_to have_been_made
  end
end
