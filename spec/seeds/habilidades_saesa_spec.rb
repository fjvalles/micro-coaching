# frozen_string_literal: true

require "rails_helper"

# The seed file auto-runs `Seeds::HabilidadesSaesa.call` at load time, so `load`ing
# it (re)seeds against the transactional test DB.
RSpec.describe "Seeds::HabilidadesSaesa", type: :model do
  def seed!
    load Rails.root.join("db/seeds/programs/habilidades_saesa.rb")
  end

  let(:program) { Program.find_by(slug: "habilidades-saesa") }

  before { seed! }

  describe "program + company" do
    it "creates the SAESA company-scoped 7-day program" do
      expect(program).to be_present
      expect(program.total_days).to eq(7)
      expect(program.company.slug).to eq("saesa")
      expect(program.response_mode).to eq("approve")
      expect(program).to be_active
      expect(program.template).to be(false)
    end

    it "is idempotent across re-runs" do
      expect { seed! }.not_to(change { Program.where(slug: "habilidades-saesa").count })
      expect(Company.where(slug: "saesa").count).to eq(1)
      expect(program.day_contents.count).to eq(7)
    end
  end

  describe "day contents" do
    it "seeds 7 days with the diagnostic → GROW → close phase arc" do
      phases = program.day_contents.ordered.map { |d| d.phase.to_sym }
      expect(phases).to eq(%i[see see choose choose choose anchor anchor])
    end

    # DayAdvancer only advances current_day when a checkin_response exists for the
    # day, so every day must ship a check-in or the participant gets stuck.
    it "gives every day a check-in so DayAdvancer can advance" do
      program.day_contents.ordered.each do |d|
        expect(d.checkin_questions).to be_present, "day #{d.day_number} needs a check-in to advance"
      end
    end

    it "reuses existing WhatsApp templates (7 days ≤ the 14-template cycle)" do
      program.day_contents.ordered.each do |d|
        expect(d.template_name_whatsapp).to eq(format("despertar_dia_%02d", d.day_number))
      end
    end

    it "embeds the GROW skill catalogue and the pick-3 rule in the day-2 prompt" do
      day2 = program.day_contents.find_by(day_number: 2)
      expect(day2.ai_system_prompt).to include("Comunicación de malas noticias")
      expect(day2.ai_system_prompt).to include("3 habilidades")
    end

    it "does not send an iareto (challenge) message on any day" do
      program.day_contents.ordered.each do |d|
        expect(d.iareto_text).to be_blank
      end
    end
  end

  describe "participant integration" do
    let(:participant) do
      create(:participant, program: program, company: program.company, current_day: 1, name: "Marcela")
    end

    it "resolves day content and phase from current_day" do
      expect(participant.day_content.day_number).to eq(1)
      expect(participant.phase).to eq(:see)
    end

    it "produces a personalized day-1 morning message (dry run, no OpenAI)" do
      result = Openai::MorningMessageGenerator.new(
        participant: participant, day_content: participant.day_content
      ).call(dry_run: true)

      expect(result.body).to include("Marcela")
      expect(result.model).to eq("dry-run")
    end
  end

  describe "ENV-driven assignment" do
    let!(:participant) { create(:participant, current_day: 4, status: :paused) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PARTICIPANT_ID").and_return(participant.id)
      allow(ENV).to receive(:[]).with("ROLE").and_return("Jefe de proyectos de distribución")
      allow(ENV).to receive(:[]).with("SCHEDULE_FIRST_DAY").and_return(nil)
    end

    it "moves the participant onto SAESA at day 1 and stores the role as focus_hint" do
      seed!
      participant.reload

      expect(participant.program).to eq(program)
      expect(participant.company).to eq(program.company)
      expect(participant.status).to eq("active")
      expect(participant.current_day).to eq(1)
      expect(participant.focus_hint).to include("Jefe de proyectos de distribución")
    end
  end
end
