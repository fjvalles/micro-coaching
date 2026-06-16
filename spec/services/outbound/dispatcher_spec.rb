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

    it "reports failed text sends as not delivered" do
      allow_any_instance_of(Whatsapp::Client).to receive(:send_text).and_return(
        Whatsapp::Client::Response.new(success?: false, error: "text body is required")
      )

      result = described_class.new(participant: participant, moment: :free_assistant).send_text(body: "")

      expect(result.delivered?).to be false
      expect(result.conversation.error_message).to eq("text body is required")
      expect(result.conversation.sent_at).to be_nil
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

    it "appends an approved catalog resource and enables preview when configured" do
      Setting.set("resource_catalog_enabled", true)
      Setting.set("link_preview_enabled", true)
      resource = create(:resource, url: "https://example.com/foco", topics: [ "foco" ])

      expect_any_instance_of(Whatsapp::Client).to receive(:send_text)
        .with(to: participant.phone_e164, body: "Mira esto\n\nhttps://example.com/foco", preview_url: true)
        .and_return(Whatsapp::Client::Response.new(success?: true, wamid: "wamid.resource"))

      result = described_class.new(participant: participant, moment: :free_assistant).send_text(
        body: "Mira esto",
        ai: { resource_catalog: true },
        resource_id: resource.id
      )

      expect(result.delivered?).to be true
      expect(ResourceDelivery.find_by(resource: resource, conversation: result.conversation)).to be_present
    end

    it "strips hallucinated URLs when catalog output has no sendable resource" do
      Setting.set("resource_catalog_enabled", true)

      expect_any_instance_of(Whatsapp::Client).to receive(:send_text)
        .with(to: participant.phone_e164, body: "Lee esto", preview_url: false)
        .and_return(Whatsapp::Client::Response.new(success?: true, wamid: "wamid.clean"))

      described_class.new(participant: participant, moment: :free_assistant).send_text(
        body: "Lee esto https://made-up.test",
        ai: { resource_catalog: true },
        resource_id: nil
      )
    end
  end

  describe "#send_template" do
    it "reports failed template sends as not delivered" do
      allow_any_instance_of(Whatsapp::Client).to receive(:send_template).and_return(
        Whatsapp::Client::Response.new(success?: false, error: "bad template params")
      )

      result = described_class.new(participant: participant, moment: :checkin_question).send_template(
        template_name: "checkin_dia_01", variables: [ "Ana", "P1" ], body_preview: "P1"
      )

      expect(result.delivered?).to be false
      expect(result.conversation.error_message).to eq("bad template params")
      expect(result.conversation.sent_at).to be_nil
    end

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
