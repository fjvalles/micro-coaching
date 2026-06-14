require "rails_helper"

RSpec.describe ProgramAssistant::ActExecutor do
  let(:admin) { create(:admin_user) }
  let(:session) { admin.program_assistant_sessions.create!(status: :active) }

  def pending(tool_name, args)
    session.program_assistant_pending_actions.create!(tool_name: tool_name, args: args, status: :pending)
  end

  describe "create_program" do
    let(:spec) do
      {
        "name" => "Calma Diaria",
        "description" => "Bajar el ruido mental",
        "manifesto" => "Eliges la calma cada día.",
        "total_days" => 2,
        "days" => [
          { "day_number" => 1, "phase" => "see", "title" => "Observar", "iareto_text" => "Nota el patrón" },
          { "day_number" => 2, "phase" => "choose", "title" => "Elegir", "morning_template" => "Buen día" }
        ]
      }
    end

    it "creates a live, inactive program with its day contents" do
      action = pending("create_program", spec)
      expect { described_class.new(action).call }.to change(Program, :count).by(1)

      program = Program.find_by(slug: "calma-diaria")
      expect(program.template).to be(false)
      expect(program.active).to be(false)
      expect(program.day_contents.count).to eq(2)
      expect(action.reload).to be_executed
    end

    it "rejects duplicate day_numbers and marks the action failed" do
      bad = spec.merge("days" => [
        { "day_number" => 1, "phase" => "see", "title" => "A" },
        { "day_number" => 1, "phase" => "see", "title" => "B" }
      ])
      action = pending("create_program", bad)
      expect { described_class.new(action).call }.not_to change(Program, :count)
      expect(action.reload).to be_failed
      expect(action.result["error"]).to match(/duplicado/)
    end

    it "rejects an invalid phase" do
      bad = spec.merge("days" => [ { "day_number" => 1, "phase" => "wrong", "title" => "A" } ])
      action = pending("create_program", bad)
      described_class.new(action).call
      expect(action.reload).to be_failed
    end

    it "is a no-op if the action is not pending" do
      action = pending("create_program", spec)
      action.update!(status: :executed)
      expect { described_class.new(action).call }.not_to change(Program, :count)
    end
  end

  describe "update_program" do
    it "updates metadata and upserts days by day_number" do
      program = create(:program, slug: "foco", manifesto: "viejo")
      create(:day_content, program: program, day_number: 1, title: "Original")

      action = pending("update_program", {
        "slug" => "foco",
        "manifesto" => "nuevo manifiesto",
        "days" => [
          { "day_number" => 1, "phase" => "see", "title" => "Reescrito" },
          { "day_number" => 2, "phase" => "anchor", "title" => "Nuevo día" }
        ]
      })

      described_class.new(action).call

      program.reload
      expect(program.manifesto).to eq("nuevo manifiesto")
      expect(program.day_contents.find_by(day_number: 1).title).to eq("Reescrito")
      expect(program.day_contents.find_by(day_number: 2).title).to eq("Nuevo día")
      expect(action.reload).to be_executed
    end

    it "fails cleanly on an unknown program" do
      action = pending("update_program", { "slug" => "no-existe", "name" => "x" })
      described_class.new(action).call
      expect(action.reload).to be_failed
      expect(action.result["error"]).to match(/no encontrado/)
    end
  end
end
