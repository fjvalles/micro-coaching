require "rails_helper"

RSpec.describe Conversations::QualityScorer do
  let(:participant) { create(:participant) }

  def free_message(role:, body:, created_at:)
    create(
      :conversation,
      participant: participant,
      role: role,
      moment: role == :assistant ? :free_assistant : :free_user,
      body: body,
      created_at: created_at
    )
  end

  it "penalizes compound questions and repeated acknowledgments" do
    conversations = [
      free_message(role: :user, body: "Me cuesta partir", created_at: 4.minutes.ago),
      free_message(role: :assistant, body: "Gracias por decirlo. ¿Qué notas en el cuerpo y qué harás ahora?", created_at: 3.minutes.ago),
      free_message(role: :user, body: "No sé", created_at: 2.minutes.ago),
      free_message(role: :assistant, body: "Gracias por decirlo. ¿A qué hora lo harás?", created_at: 1.minute.ago)
    ]

    result = described_class.new(conversations: conversations).call

    expect(result.score).to be < 100
    expect(result.subscores[:compound_questions]).to be < 100
    expect(result.subscores[:repeated_acknowledgments]).to be < 100
    expect(result.examples.map { |e| e[:type] }).to include("compound_questions")
  end

  it "returns a perfect score for an empty sample" do
    result = described_class.new(conversations: []).call

    expect(result.score).to eq(100)
    expect(result.sample_size).to eq(0)
  end
end
