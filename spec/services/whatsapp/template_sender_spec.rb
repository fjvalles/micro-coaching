require "rails_helper"

RSpec.describe Whatsapp::TemplateSender do
  let(:participant) { create(:participant, name: "Francisco J") }
  let(:client) { instance_double(Whatsapp::Client) }

  it "flattens whitespace in template parameters before sending" do
    expect(client).to receive(:send_template) do |args|
      parameter_texts = args[:components].first[:parameters].map { |param| param[:text] }

      expect(parameter_texts).to eq([
        "Francisco J",
        "¿Qué notaste sobre tus ganas de dulce hoy? ¿Hubo momentos en que te diste cuenta?"
      ])

      Whatsapp::Client::Response.new(success?: true, wamid: "wamid.OK")
    end

    described_class.new(
      participant: participant,
      template_name: "checkin_dia_01",
      moment: :checkin_reminder,
      variables: [
        "Francisco J",
        "¿Qué notaste sobre tus ganas de dulce hoy?\n\n¿Hubo momentos en que te diste cuenta?"
      ],
      client: client
    ).call

    conversation = participant.conversations.last
    expect(conversation.body).not_to include("\n")
  end
end
