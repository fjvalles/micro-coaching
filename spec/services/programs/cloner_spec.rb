require "rails_helper"

RSpec.describe Programs::Cloner do
  let(:template) do
    create(:program, template: true, generated: true, active: false, total_days: 2,
                     price_clp: 30_000, founder_price_clp: 19_000).tap do |p|
      create(:day_content, program: p, day_number: 1, phase: :see)
      create(:day_content, program: p, day_number: 2, phase: :anchor)
    end
  end

  it "deep-copies the template into a live program" do
    clone = described_class.new(template: template).call

    expect(clone.id).not_to eq(template.id)
    expect(clone.template).to be(false)
    expect(clone.generated).to be(true)
    expect(clone.active).to be(true)
    expect(clone.day_contents.count).to eq(2)
  end

  it "carries the price columns onto the clone (so the paid Nivel 2 keeps its price)" do
    clone = described_class.new(template: template).call

    expect(clone.price_clp).to eq(30_000)
    expect(clone.founder_price_clp).to eq(19_000)
    expect(clone.paid?).to be(true)
  end
end
