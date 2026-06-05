require "rails_helper"

RSpec.describe TagConversationSkillsJob do
  let(:participant) { create(:participant) }
  let!(:skill) { create(:skill, slug: "escucha_activa", name: "Escucha activa") }
  let(:conversation) do
    create(:conversation, participant: participant, moment: :free_user, role: :user, body: "no escuché a mi equipo")
  end

  def stub_tagger(tags)
    result = Openai::SkillTagger::Result.new(tags: tags)
    allow_any_instance_of(Openai::SkillTagger).to receive(:call).and_return(result)
  end

  it "persists a detection per returned tag above the confidence floor" do
    stub_tagger([ Openai::SkillTagger::Tag.new(slug: "escucha_activa", confidence: 0.9) ])

    expect { described_class.new.perform(conversation.id) }.to change(SkillDetection, :count).by(1)
    detection = SkillDetection.last
    expect(detection.skill).to eq(skill)
    expect(detection.source).to eq("free_user")
  end

  it "drops tags below the minimum confidence" do
    Setting.set("skill_tagging_min_confidence", 0.6)
    stub_tagger([ Openai::SkillTagger::Tag.new(slug: "escucha_activa", confidence: 0.4) ])

    expect { described_class.new.perform(conversation.id) }.not_to change(SkillDetection, :count)
  end

  it "is idempotent — skips a conversation that already has detections" do
    create(:skill_detection, participant: participant, conversation: conversation, skill: skill)
    expect_any_instance_of(Openai::SkillTagger).not_to receive(:call)

    expect { described_class.new.perform(conversation.id) }.not_to change(SkillDetection, :count)
  end

  it "does nothing when the kill-switch is off" do
    Setting.set("skill_tagging_enabled", false)
    expect_any_instance_of(Openai::SkillTagger).not_to receive(:call)

    expect { described_class.new.perform(conversation.id) }.not_to change(SkillDetection, :count)
  end
end
