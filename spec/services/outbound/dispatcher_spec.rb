require "rails_helper"

RSpec.describe Outbound::Dispatcher do
  let(:participant) { create(:participant) }

  before do
    PendingResponse.delete_all
    Setting.set("response_mode", "auto")
    allow_any_instance_of(Whatsapp::Client).to receive(:send_text).and_return(
      Whatsapp::Client::Response.new(success?: true, wamid: "wamid.test")
    )
  end

  describe "#send_text" do
    it "delivers immediately in auto mode" do
      result = described_class.new(participant: participant, moment: :free_assistant).send_text(body: "hola")
      expect(result.delivered?).to be true
      expect(result.conversation).to be_persisted
      expect(PendingResponse.count).to eq(0)
    end

    it "queues PendingResponse in approve mode" do
      participant.update!(response_mode: "approve")
      result = described_class.new(participant: participant, moment: :free_assistant).send_text(body: "hola")
      expect(result.delivered?).to be false
      expect(result.queued?).to be true
      expect(result.pending_response.status).to eq("pending")
      expect(result.pending_response.mode).to eq("approve")
    end

    it "queues empty draft in manual mode" do
      participant.update!(response_mode: "manual")
      result = described_class.new(participant: participant, moment: :free_assistant).send_text(body: "")
      expect(result.queued?).to be true
      expect(result.pending_response.draft_body).to eq("")
    end
  end

  describe "#send_template" do
    it "queues template pending in suggest mode" do
      participant.update!(response_mode: "suggest")
      result = described_class.new(participant: participant, moment: :morning_wake).send_template(
        template_name: "test", variables: [ "n", "b" ], body_preview: "b"
      )
      expect(result.queued?).to be true
      expect(result.pending_response.delivery_kind).to eq("template")
      expect(result.pending_response.template_name).to eq("test")
    end
  end
end
