# frozen_string_literal: true

require "rails_helper"

RSpec.describe Whatsapp::DailyTemplateName do
  describe ".call" do
    it "uses the same day inside the approved cycle" do
      expect(described_class.call(prefix: "checkin", day_number: 7)).to eq("checkin_dia_07")
    end

    it "cycles days beyond the approved template set" do
      expect(described_class.call(prefix: "checkin", day_number: 15)).to eq("checkin_dia_01")
      expect(described_class.call(prefix: "iareto", day_number: 56)).to eq("iareto_dia_14")
    end

    it "keeps custom configured names" do
      expect(
        described_class.call(prefix: "despertar", day_number: 15, configured_name: "despertar_cerebro")
      ).to eq("despertar_cerebro")
    end

    it "cycles configured standard daily names" do
      expect(
        described_class.call(prefix: "despertar", day_number: 15, configured_name: "despertar_dia_15")
      ).to eq("despertar_dia_01")
    end
  end
end
