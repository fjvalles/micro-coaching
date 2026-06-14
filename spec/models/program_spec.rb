require "rails_helper"

RSpec.describe Program, type: :model do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to belong_to(:company).optional }

  describe "company scoping" do
    let(:company)       { create(:company) }
    let(:other_company) { create(:company) }
    let!(:general)      { create(:program, company: nil) }
    let!(:company_only) { create(:program, company: company) }
    let!(:other_only)   { create(:program, company: other_company) }

    it ".general includes general programs and excludes company programs" do
      expect(Program.general).to include(general)
      expect(Program.general).not_to include(company_only)
    end

    it ".for_company returns only that company's programs" do
      expect(Program.for_company(company)).to contain_exactly(company_only)
    end

    it ".available_to includes general + the company's own, excludes other companies'" do
      result = Program.available_to(company)
      expect(result).to include(general, company_only)
      expect(result).not_to include(other_only)
    end

    it ".available_to(nil) includes general programs and excludes company programs" do
      result = Program.available_to(nil)
      expect(result).to include(general)
      expect(result).not_to include(company_only)
    end

    it "#general? reflects company presence" do
      expect(general.general?).to be true
      expect(company_only.general?).to be false
    end
  end

  describe ".default" do
    it "returns a general (non-company) active program" do
      create(:program, company: create(:company), active: true)
      create(:program, company: nil, active: true)
      expect(Program.default).to be_present
      expect(Program.default.general?).to be true
    end

    it "never returns a generated template even if it is the oldest active general program" do
      create(:program, company: nil, active: true, template: true, generated: true, created_at: 100.years.ago)
      expect(Program.default).to be_present
      expect(Program.default.template).to be(false)
    end
  end

  describe ".available_to" do
    it "excludes generated templates even when active" do
      create(:program, company: nil, active: true, template: true, generated: true)
      live = create(:program, company: nil, active: true)
      expect(Program.available_to(nil)).to include(live)
      expect(Program.available_to(nil).where(template: true)).to be_empty
    end
  end

  describe "#paid?" do
    it "is false when price_clp is zero (free trial)" do
      expect(build(:program, price_clp: 0).paid?).to be(false)
    end

    it "is true when price_clp is positive" do
      expect(build(:program, price_clp: 25_000).paid?).to be(true)
    end
  end

  describe "#effective_price_clp" do
    let(:program) { build(:program, price_clp: 30_000, founder_price_clp: 19_000) }

    it "returns the founder price inside the founder window" do
      expect(program.effective_price_clp(within_founder_window: true)).to eq(19_000)
    end

    it "returns the standing price outside the window" do
      expect(program.effective_price_clp(within_founder_window: false)).to eq(30_000)
    end

    it "falls back to the standing price when no founder price is set" do
      program.founder_price_clp = 0
      expect(program.effective_price_clp(within_founder_window: true)).to eq(30_000)
    end
  end
end
