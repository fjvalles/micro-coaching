require "rails_helper"

RSpec.describe Outbound::AdminMessage do
  let(:participant) { create(:participant) }

  before do
    Setting.set("response_mode", "auto")
    allow_any_instance_of(Whatsapp::Client).to receive(:send_text).and_return(
      Whatsapp::Client::Response.new(success?: true, wamid: "wamid.text")
    )
    allow_any_instance_of(Whatsapp::Client).to receive(:send_template).and_return(
      Whatsapp::Client::Response.new(success?: true, wamid: "wamid.tpl")
    )
  end

  # Puts the participant inside the 24h free-form window.
  def open_window!
    create(:conversation, participant: participant, role: :user, created_at: 1.hour.ago)
  end

  describe "free text" do
    it "sends and records an admin_manual conversation when inside the 24h window" do
      open_window!
      result = described_class.new(participant: participant, kind: "text", body: "Hola directo").call

      expect(result.sent?).to be true
      convo = result.conversation
      expect(convo.moment).to eq("admin_manual")
      expect(convo.role).to eq("assistant")
      expect(convo.body).to eq("Hola directo")
      expect(convo.sent_at).to be_present
    end

    it "skips outside the 24h window" do
      result = described_class.new(participant: participant, kind: "text", body: "Hola").call

      expect(result.sent?).to be false
      expect(result.skipped_reason).to eq(:outside_24h_window)
      expect(Conversation.where(moment: :admin_manual).count).to eq(0)
    end

    it "skips a blank body before checking the window" do
      result = described_class.new(participant: participant, kind: "text", body: "  ").call
      expect(result.skipped_reason).to eq(:blank_body)
    end

    it "reports send_failed when Meta rejects (kill-switch / error)" do
      open_window!
      allow_any_instance_of(Whatsapp::Client).to receive(:send_text).and_return(
        Whatsapp::Client::Response.new(success?: false, error: "kill-switch")
      )
      result = described_class.new(participant: participant, kind: "text", body: "Hola").call

      expect(result.sent?).to be false
      expect(result.skipped_reason).to eq(:send_failed)
      expect(result.error).to eq("kill-switch")
    end
  end

  describe "template" do
    it "sends a template regardless of the 24h window" do
      result = described_class.new(
        participant: participant, kind: "template", template_name: "bienvenida_piloto", variables: [ "Ana" ]
      ).call

      expect(result.sent?).to be true
      expect(result.conversation.whatsapp_template_name).to eq("bienvenida_piloto")
    end

    it "skips when no template chosen" do
      result = described_class.new(participant: participant, kind: "template", template_name: "").call
      expect(result.skipped_reason).to eq(:no_template)
    end
  end
end
