require "rails_helper"

RSpec.describe Company, type: :model do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to have_many(:participants) }
  it { is_expected.to have_many(:programs) }

  it "auto-generates slug from name on create" do
    c = Company.create!(name: "Acme Latam")
    expect(c.slug).to eq("acme-latam")
  end

  it "rejects an invalid slug format" do
    expect(build(:company, slug: "Bad Slug")).not_to be_valid
  end

  it "enforces slug uniqueness" do
    create(:company, slug: "dup")
    expect(build(:company, slug: "dup")).not_to be_valid
  end

  describe "#resolved_coach_name" do
    before { Setting.set("coach_name", "GlobalBot") }

    it "prefers the per-company coach_name" do
      expect(build(:company, coach_name: "Sofía").resolved_coach_name).to eq("Sofía")
    end

    it "falls back to the global Setting when blank" do
      expect(build(:company, coach_name: "").resolved_coach_name).to eq("GlobalBot")
    end
  end

  describe "soft delete" do
    it "excludes discarded from kept" do
      c = create(:company)
      c.discard
      expect(Company.kept).not_to include(c)
    end
  end
end
