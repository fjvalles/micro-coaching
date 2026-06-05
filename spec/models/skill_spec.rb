require "rails_helper"

RSpec.describe Skill do
  it "requires a unique slug and a name" do
    create(:skill, slug: "escucha_activa")
    dup = build(:skill, slug: "escucha_activa")
    expect(dup).not_to be_valid

    expect(build(:skill, name: nil)).not_to be_valid
  end

  it "orders by position then name" do
    b = create(:skill, position: 2, name: "B")
    a = create(:skill, position: 1, name: "A")
    expect(Skill.ordered.to_a).to eq([ a, b ])
  end

  it "exposes detection counts" do
    skill = create(:skill)
    create_list(:skill_detection, 2, skill: skill)
    row = Skill.with_detection_counts.find(skill.id)
    expect(row.detections_count).to eq(2)
  end
end
