require "rails_helper"

RSpec.describe Whatsapp::AdminTemplateCatalog do
  describe "#call" do
    let(:program) { create(:program) }
    let(:participant) { build(:participant, program: program, name: "Ana") }

    before do
      create(:day_content, program: program, day_number: 1,
             template_name_whatsapp: "despertar_dia_01",
             iareto_text: "Reto día 1", checkin_questions: "1. P1\n2. P2\n3. P3\n4. P4")
      create(:day_content, program: program, day_number: 2,
             template_name_whatsapp: "despertar_dia_02",
             iareto_text: "Reto día 2", checkin_questions: "1. Q1")
    end

    subject(:catalog) { described_class.new(participant: participant).call }

    it "always includes the welcome template first, prefilled with the name" do
      welcome = catalog.first
      expect(welcome["name"]).to eq("bienvenida_piloto")
      expect(welcome["variables"]).to eq([ { "label" => "Nombre", "default" => "Ana" } ])
    end

    it "derives despertar/iareto/checkin per active day in order" do
      names = catalog.map { |t| t["name"] }
      expect(names).to eq(%w[
        bienvenida_piloto
        despertar_dia_01 iareto_dia_01 checkin_dia_01
        despertar_dia_02 iareto_dia_02 checkin_dia_02
      ])
    end

    it "prefills the iareto template with the day's text" do
      iareto = catalog.find { |t| t["name"] == "iareto_dia_01" }
      expect(iareto["variables"]).to eq([
        { "label" => "Nombre", "default" => "Ana" },
        { "label" => "Texto IARETO", "default" => "Reto día 1" }
      ])
    end

    it "prefills the check-in template with the first three question lines" do
      checkin = catalog.find { |t| t["name"] == "checkin_dia_01" }
      questions = checkin["variables"].last
      expect(questions["label"]).to eq("Preguntas")
      expect(questions["default"]).to eq("1. P1\n\n2. P2\n\n3. P3")
    end

    it "removes duplicated greetings from day-content template variables" do
      program.day_contents.find_by(day_number: 1).update!(
        iareto_text: "Hola Ana, toma una pausa breve.\n\n— Impulso Coach",
        checkin_questions: "Buenas noches, Ana. 1. ¿Qué notaste?\n2. ¿Qué eliges mañana?\n\nImpulso"
      )

      result = described_class.new(participant: participant).call
      iareto = result.find { |t| t["name"] == "iareto_dia_01" }
      checkin = result.find { |t| t["name"] == "checkin_dia_01" }

      expect(iareto["variables"].last["default"]).to eq("toma una pausa breve.")
      expect(checkin["variables"].last["default"]).to eq("1. ¿Qué notaste?\n\n2. ¿Qué eliges mañana?")
    end

    it "leaves the morning message blank (AI-generated)" do
      despertar = catalog.find { |t| t["name"] == "despertar_dia_01" }
      expect(despertar["variables"].last).to eq({ "label" => "Mensaje", "default" => "" })
    end

    it "falls back to despertar_dia_NN when template_name_whatsapp is blank" do
      create(:day_content, program: program, day_number: 3,
             template_name_whatsapp: nil, iareto_text: nil, checkin_questions: nil)
      names = described_class.new(participant: participant).call.map { |t| t["name"] }
      expect(names).to include("despertar_dia_03")
    end

    it "skips iareto/checkin when their content is blank" do
      create(:day_content, program: program, day_number: 3,
             template_name_whatsapp: "despertar_dia_03",
             iareto_text: nil, checkin_questions: nil)
      day3 = described_class.new(participant: participant).call.map { |t| t["name"] }.grep(/_03\z/)
      expect(day3).to eq(%w[despertar_dia_03])
    end

    it "ignores inactive days" do
      create(:day_content, program: program, day_number: 3,
             template_name_whatsapp: "despertar_dia_03", active: false)
      names = described_class.new(participant: participant).call.map { |t| t["name"] }
      expect(names).not_to include("despertar_dia_03")
    end

    context "with curated Setting templates" do
      it "appends them after program templates and dedupes by name" do
        Setting.set("admin_message_templates", [
          { "name" => "promo_especial", "label" => "Promo", "variables" => [ "Cupon" ] },
          { "name" => "bienvenida_piloto", "label" => "dup", "variables" => [] }
        ])
        result = described_class.new(participant: participant).call
        names = result.map { |t| t["name"] }

        expect(names).to include("promo_especial")
        expect(names.count("bienvenida_piloto")).to eq(1)

        promo = result.find { |t| t["name"] == "promo_especial" }
        expect(promo["variables"]).to eq([ { "label" => "Cupon", "default" => "" } ])
      end
    end

    context "without a participant (broadcast)" do
      it "lists only welcome and curated Setting templates" do
        Setting.set("admin_message_templates", [
          { "name" => "promo_especial", "label" => "Promo", "variables" => [] }
        ])
        names = described_class.new.call.map { |t| t["name"] }
        expect(names).to eq(%w[bienvenida_piloto promo_especial])
      end

      it "leaves the welcome name default blank" do
        welcome = described_class.new.call.first
        expect(welcome["variables"]).to eq([ { "label" => "Nombre", "default" => "" } ])
      end
    end

    context "when the participant has no program" do
      it "still offers the welcome template" do
        names = described_class.new(participant: build(:participant, program: nil)).call.map { |t| t["name"] }
        expect(names).to eq(%w[bienvenida_piloto])
      end
    end
  end
end
