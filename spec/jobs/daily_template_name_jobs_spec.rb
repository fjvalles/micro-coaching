# frozen_string_literal: true

require "rails_helper"

RSpec.describe "daily template name usage", type: :job do
  let(:program) { create(:program, total_days: 56) }
  let(:participant) { create(:participant, :active, program: program, current_day: 15) }

  before do
    create(
      :day_content,
      program: program,
      day_number: 15,
      template_name_whatsapp: "despertar_dia_15",
      iareto_text: "Haz el primer paso.",
      checkin_questions: "1. Dormiste bien?\n2. Hiciste el reto?"
    )
  end

  it "cycles the morning wake template for long programs" do
    allow_any_instance_of(Openai::MorningMessageGenerator).to receive(:call).and_return(
      Openai::MorningMessageGenerator::Result.new(
        body: "Mensaje breve.",
        prompt_used: "prompt",
        tokens_input: 1,
        tokens_output: 1,
        model: "test-model"
      )
    )

    sent = []
    allow_any_instance_of(Outbound::Dispatcher).to receive(:send_template) do |_dispatcher, args|
      sent << args[:template_name]
      Outbound::Dispatcher::Result.new(delivered: true, conversation: build(:conversation))
    end

    described_class = MorningWakeForParticipantJob
    described_class.new.perform(participant.id)

    expect(sent).to include("despertar_dia_01")
  end

  it "cycles the IAReto template for long programs outside the 24h window" do
    sent = []
    allow_any_instance_of(Outbound::Dispatcher).to receive(:send_template) do |_dispatcher, args|
      sent << args[:template_name]
      Outbound::Dispatcher::Result.new(delivered: true, conversation: build(:conversation))
    end

    SendIaretoJob.new.perform(participant.id)

    expect(sent).to eq([ "iareto_dia_01" ])
  end

  it "strips duplicated greetings from IAReto template variables" do
    participant.update!(name: "Francisco J")
    participant.day_content.update!(iareto_text: "Hola Francisco J, anota una pausa breve.\n\n— Impulso Coach")
    sent_variables = []
    allow_any_instance_of(Outbound::Dispatcher).to receive(:send_template) do |_dispatcher, args|
      sent_variables = args[:variables]
      Outbound::Dispatcher::Result.new(delivered: true, conversation: build(:conversation))
    end

    SendIaretoJob.new.perform(participant.id)

    expect(sent_variables).to eq([ "Francisco J", "anota una pausa breve." ])
  end

  it "cycles the check-in template for long programs outside the 24h window" do
    sent = []
    allow_any_instance_of(Outbound::Dispatcher).to receive(:send_template) do |_dispatcher, args|
      sent << args[:template_name]
      Outbound::Dispatcher::Result.new(delivered: true, conversation: build(:conversation))
    end

    CheckinForParticipantJob.new.perform(participant.id)

    expect(sent).to eq([ "checkin_dia_01" ])
  end

  it "strips duplicated greetings from check-in template variables" do
    participant.update!(name: "Francisco J")
    participant.day_content.update!(
      checkin_questions: "Buenas noches, Francisco J. 1. ¿Qué observaste?\n2. ¿Qué eliges mañana?\n\nImpulso"
    )
    sent_variables = []
    allow_any_instance_of(Outbound::Dispatcher).to receive(:send_template) do |_dispatcher, args|
      sent_variables = args[:variables]
      Outbound::Dispatcher::Result.new(delivered: true, conversation: build(:conversation))
    end

    CheckinForParticipantJob.new.perform(participant.id)

    expect(sent_variables).to eq([ "Francisco J", "1. ¿Qué observaste?\n\n2. ¿Qué eliges mañana?" ])
  end
end
