require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#translate_enum" do
    it "returns the translation if it exists" do
      expect(helper.translate_enum(Participant, :status, :active)).to eq("Activo")
    end

    it "returns the humanized value if translation is missing" do
      expect(helper.translate_enum(Participant, :status, :non_existent)).to eq("Non existent")
    end

    it "returns an empty string if value is blank" do
      expect(helper.translate_enum(Participant, :status, nil)).to eq("")
    end
  end

  describe "#translate_status" do
    it "translates active status" do
      expect(helper.translate_status("active")).to eq("Activo")
    end

    it "translates pending status" do
      expect(helper.translate_status("pending")).to eq("Pendiente")
    end
  end

  describe "#translate_phase" do
    it "translates phase see" do
      expect(helper.translate_phase("see")).to eq("Ver")
    end
  end

  describe "#translate_moment" do
    it "translates morning_wake moment" do
      expect(helper.translate_moment("morning_wake")).to eq("Despertador")
    end
  end

  describe "#translate_role" do
    it "translates user role" do
      expect(helper.translate_role("user")).to eq("Usuario")
    end
  end
end
