require "rails_helper"

RSpec.describe Setting, type: :model do
  before { Rails.cache.clear }

  describe "schema integrity" do
    it "registers every key with a valid type and category" do
      described_class::SCHEMA.each do |key, spec|
        expect(described_class::VALUE_TYPES).to include(spec[:type].to_s), "type missing/invalid for #{key}"
        expect(described_class::CATEGORIES).to include(spec[:category]),   "category missing/invalid for #{key}"
        expect(spec[:description]).to be_present, "description missing for #{key}"
      end
    end
  end

  describe ".seed_defaults!" do
    it "inserts every SCHEMA entry exactly once and is idempotent" do
      described_class.delete_all
      expect { described_class.seed_defaults! }.to change(described_class, :count).by(described_class::SCHEMA.size)
      expect { described_class.seed_defaults! }.not_to change(described_class, :count)
    end
  end

  describe ".fetch (typed)" do
    before { described_class.delete_all }

    it "returns schema default when no row exists" do
      expect(described_class.fetch("wake_hour")).to eq(7)
      expect(described_class.fetch("openai_dry_run_global")).to eq(false)
      expect(described_class.fetch("openai_temperature_generative")).to eq(0.75)
    end

    it "casts integer values" do
      described_class.set("wake_hour", 9)
      expect(described_class.fetch("wake_hour")).to eq(9)
    end

    it "casts boolean values from string storage" do
      described_class.set("whatsapp_send_enabled", false)
      Rails.cache.clear
      expect(described_class.fetch("whatsapp_send_enabled")).to eq(false)
    end

    it "casts float values" do
      described_class.set("openai_temperature_json", 0.1)
      expect(described_class.fetch("openai_temperature_json")).to eq(0.1)
    end
  end

  describe ".get (legacy string accessor)" do
    it "still returns strings for backward compatibility" do
      described_class.set("wake_hour", 9)
      expect(described_class.get("wake_hour")).to eq("9")
    end
  end

  describe "validation" do
    it "rejects out-of-range wake_hour" do
      record = described_class.new(key: "wake_hour", value: "99", value_type: "integer", category: "timing")
      expect(record).not_to be_valid
      expect(record.errors[:value].join).to match(/entre 0 y 23/)
    end

    it "rejects unknown value_type" do
      record = described_class.new(key: "x", value: "1", value_type: "weird", category: "general")
      expect(record).not_to be_valid
    end

    it "rejects unknown category" do
      record = described_class.new(key: "x", value: "1", value_type: "string", category: "weird")
      expect(record).not_to be_valid
    end
  end

  describe "cache invalidation" do
    it "clears the cache on commit so subsequent reads see new value" do
      described_class.set("wake_hour", 7)
      expect(described_class.fetch("wake_hour")).to eq(7)
      described_class.set("wake_hour", 11)
      expect(described_class.fetch("wake_hour")).to eq(11)
    end
  end
end
