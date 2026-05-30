require "rails_helper"

RSpec.describe DayContent, type: :model do
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to define_enum_for(:phase).with_values(see: 0, choose: 1, anchor: 2) }

  it { is_expected.to validate_uniqueness_of(:day_number).scoped_to(:program_id) }

  it "rejects day_number < 1" do
    expect(build(:day_content, day_number: 0)).not_to be_valid
  end

  it "requires a program" do
    day_content = build(:day_content, program: nil)

    expect(day_content).not_to be_valid
    expect(day_content.errors[:program]).to include("must exist")
  end

  it "seeds 14 days for each seeded program" do
    PendingResponse.delete_all
    DayContent.delete_all
    Conversation.delete_all
    DailyReport.delete_all
    Participant.delete_all
    PromptAnalysis.delete_all
    PromptExecution.delete_all
    PromptVersion.delete_all
    PromptTemplate.delete_all
    MethodologyInsight.delete_all
    Program.delete_all
    load Rails.root.join("db/seeds/day_contents.rb")
    expect(Program.count).to eq(3)
    expect(DayContent.count).to eq(42)
    expect(Program.find_by!(slug: "impulso-liderazgo-en-accion").day_contents.count).to eq(14)
    expect(Program.find_by!(slug: "impulso-cambio-en-accion").day_contents.count).to eq(14)
    expect(Program.find_by!(slug: "impulso-productividad-sostenible").day_contents.count).to eq(14)
  end
end
