require "rails_helper"

RSpec.describe ProgramAssistant::ReadTools do
  def slugs(args = {})
    described_class.list_programs(args)[:programs].map { |p| p[:slug] }
  end

  describe ".list_programs" do
    it "lists live programs with summary fields" do
      create(:program, name: "Foco", slug: "foco", active: true)
      expect(slugs).to include("foco")
    end

    it "excludes templates" do
      create(:program, name: "Plantilla", slug: "plantilla", template: true)
      expect(slugs).not_to include("plantilla")
    end

    it "filters to active when only_active is set" do
      create(:program, slug: "pa-on", active: true)
      create(:program, slug: "pa-off", active: false)
      expect(slugs("only_active" => true)).to include("pa-on")
      expect(slugs("only_active" => true)).not_to include("pa-off")
    end
  end

  describe ".get_program" do
    it "returns the full program with ordered days, resolved by slug" do
      program = create(:program, slug: "anclaje")
      create(:day_content, program: program, day_number: 2, title: "Dos")
      create(:day_content, program: program, day_number: 1, title: "Uno")

      out = described_class.get_program("slug" => "anclaje")
      expect(out[:days].map { |d| d[:day_number] }).to eq([ 1, 2 ])
      expect(out[:days].first[:title]).to eq("Uno")
    end

    it "resolves by id" do
      program = create(:program)
      expect(described_class.get_program("program_id" => program.id)[:slug]).to eq(program.slug)
    end

    it "errors on an unknown reference (non-uuid slug does not raise)" do
      expect(described_class.get_program("program_id" => "no-existe")[:error]).to be_present
    end
  end
end
