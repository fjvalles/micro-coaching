require "rails_helper"

RSpec.describe Finances::CostCalculator do
  before do
    %w[hosting email meta_api ads other].each { |k| Setting.set("cost_#{k}_monthly_usd", 0.0) }
  end

  let(:range) { 30.days.ago.beginning_of_day..Time.current.end_of_day }

  describe "#call" do
    it "prorates manual monthly fixed costs over the range" do
      Setting.set("cost_hosting_monthly_usd", 30.0)

      result = described_class.new(range).call

      expect(result.manual_monthly[:hosting]).to eq(30.0)
      expect(result.manual_total).to be_within(2.0).of(30.0) # ~1 month
    end

    it "returns zero AI cost when there are no executions in the range" do
      result = described_class.new(range).call

      expect(result.ai_total).to eq(0.0)
      expect(result.ai_calls).to eq(0)
      expect(result.ai_by_model).to eq([])
    end

    it "totals AI plus manual costs" do
      Setting.set("cost_other_monthly_usd", 10.0)

      result = described_class.new(range).call

      expect(result.total_cost).to eq(result.ai_total + result.manual_total)
    end
  end
end
