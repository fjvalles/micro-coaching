require "rails_helper"

RSpec.describe Programs::OverviewMessage do
  let(:program) { create(:program, name: "Reset de Mañanas", total_days: 7) }
  let(:participant) { create(:participant, program: program) }

  before do
    create(:day_content, program: program, day_number: 1, phase: :see)
    create(:day_content, program: program, day_number: 2, phase: :choose)
    create(:day_content, program: program, day_number: 3, phase: :anchor)
  end

  subject(:message) { described_class.new(participant).call }

  it "states the program name and duration" do
    expect(message).to include("Reset de Mañanas")
    expect(message).to include("7 días")
  end

  it "describes the daily cadence so the participant knows what to expect" do
    expect(message).to include("Cada mañana")
    expect(message).to include("check-in")
  end

  it "lists the see→choose→anchor arc in order" do
    expect(message.index("Ver")).to be < message.index("Elegir")
    expect(message.index("Elegir")).to be < message.index("Anclar")
  end

  it "does not leak specific future-day challenge content" do
    expect(message).not_to include(create(:day_content, program: program, day_number: 4, phase: :choose, iareto_text: "RETO-SECRETO-DIA-4").iareto_text)
  end

  it "only lists the phases the program actually uses" do
    only_see = create(:program, total_days: 2)
    create(:day_content, program: only_see, day_number: 1, phase: :see)
    create(:day_content, program: only_see, day_number: 2, phase: :see)
    p = create(:participant, program: only_see)

    msg = described_class.new(p).call
    expect(msg).to include("Ver")
    expect(msg).not_to include("Elegir")
    expect(msg).not_to include("Anclar")
  end

  it "appends the coach sign-off when a coach name is set" do
    allow(Setting).to receive(:fetch).and_call_original
    allow(Setting).to receive(:fetch).with("coach_name").and_return("Maru")
    expect(described_class.new(participant).call).to include("Maru")
  end

  it "returns nil when the participant has no program" do
    expect(described_class.new(create(:participant, program: nil, status: :pending)).call).to be_nil
  end
end
