require "rails_helper"

RSpec.describe ProcessIncomingMessageJob, type: :job do
  let(:participant) { create(:participant, phone_e164: "+5215551234567", initial_pattern: "X") }

  def text_payload(from: "5215551234567", text: "Hola")
    {
      "entry" => [ { "changes" => [ { "value" => { "messages" => [
        { "from" => from, "id" => "wamid.#{SecureRandom.hex(4)}", "timestamp" => Time.now.to_i.to_s,
          "type" => "text", "text" => { "body" => text } }
      ] } } ] } ]
    }
  end

  before do
    PendingResponse.delete_all
    DailyReport.delete_all
    Conversation.delete_all
    Participant.delete_all
    UnknownInbound.delete_all
    ENV["META_PHONE_NUMBER_ID"] = "1234"
    ENV["META_ACCESS_TOKEN"] = "tok"
    Setting.set("inbound_intent_classification_enabled", false)
    Setting.set("inbound_intent_min_confidence", 0.65)
    stub_request(:post, "https://graph.facebook.com/v21.0/1234/messages")
      .to_return(status: 200, body: { messages: [ { id: "wamid.OUT" } ] }.to_json)
  end

  it "creates UnknownInbound record for unregistered phone" do
    expect {
      described_class.new.perform(text_payload(from: "999999"))
    }.to change(UnknownInbound, :count).by(1)

    record = UnknownInbound.last
    expect(record.phone).to eq("+999999")
    expect(record.message_type).to eq("text")
    expect(record.body_preview).to eq("Hola")
    expect(Conversation.count).to eq(0)
  end

  it "does not duplicate UnknownInbound on repeated webhook delivery" do
    payload = text_payload(from: "999999")
    described_class.new.perform(payload)
    expect {
      described_class.new.perform(payload)
    }.not_to change(UnknownInbound, :count)
  end

  describe "WhatsApp-first self-signup" do
    def signup_payload(from: "56999000111", name: "Ana Pérez")
      {
        "entry" => [ { "changes" => [ { "value" => {
          "contacts" => [ { "wa_id" => from, "profile" => { "name" => name } } ],
          "messages" => [ { "from" => from, "id" => "wamid.#{SecureRandom.hex(4)}",
                            "timestamp" => Time.now.to_i.to_s, "type" => "text", "text" => { "body" => "Quiero empezar" } } ]
        } } ] } ]
      }
    end

    before do
      Setting.set("whatsapp_self_signup_enabled", true)
      Setting.set("membership_price_clp", 0) # door free → activates immediately
      create(:program)
    end

    it "enrolls a brand-new participant from the WhatsApp profile name and skips UnknownInbound" do
      expect {
        described_class.new.perform(signup_payload)
      }.to change(Participant, :count).by(1)
      expect(UnknownInbound.count).to eq(0)

      p = Participant.find_by(phone_e164: "+56999000111")
      expect(p.name).to eq("Ana Pérez")
      expect(p).to be_active
    end

    it "falls back to a placeholder name when the profile name is missing" do
      payload = signup_payload
      payload["entry"][0]["changes"][0]["value"].delete("contacts")
      described_class.new.perform(payload)
      expect(Participant.find_by(phone_e164: "+56999000111").name).to eq("Nuevo participante")
    end

    it "stays a no-op (UnknownInbound) when the kill-switch is off" do
      Setting.set("whatsapp_self_signup_enabled", false)
      expect {
        described_class.new.perform(signup_payload)
      }.to change(UnknownInbound, :count).by(1)
      expect(Participant.where(phone_e164: "+56999000111")).to be_empty
    end
  end

  it "stores inbound from known participant" do
    allow_any_instance_of(Openai::FreeResponseGenerator).to receive(:call).and_return(
      Openai::FreeResponseGenerator::Result.new(body: "respondido", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
    )
    participant
    described_class.new.perform(text_payload(text: "hola"))
    expect(participant.conversations.where(role: :user).count).to eq(1)
    expect(participant.conversations.where(role: :assistant).count).to eq(1)
  end

  it "enqueues skill tagging for the inbound free message" do
    allow_any_instance_of(Openai::FreeResponseGenerator).to receive(:call).and_return(
      Openai::FreeResponseGenerator::Result.new(body: "r", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
    )
    participant
    expect {
      described_class.new.perform(text_payload(text: "hola"))
    }.to have_enqueued_job(TagConversationSkillsJob)
  end

  it "does not enqueue skill tagging when the kill-switch is off" do
    Setting.set("skill_tagging_enabled", false)
    allow_any_instance_of(Openai::FreeResponseGenerator).to receive(:call).and_return(
      Openai::FreeResponseGenerator::Result.new(body: "r", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
    )
    participant
    expect {
      described_class.new.perform(text_payload(text: "hola"))
    }.not_to have_enqueued_job(TagConversationSkillsJob)
  end

  def audio_payload(from: "5215551234567", media_id: "MID-1")
    {
      "entry" => [ { "changes" => [ { "value" => { "messages" => [
        { "from" => from, "id" => "wamid.#{SecureRandom.hex(4)}", "timestamp" => Time.now.to_i.to_s,
          "type" => "audio", "audio" => { "id" => media_id, "mime_type" => "audio/ogg" } }
      ] } } ] } ]
    }
  end

  it "processes audio: transcribes, persists analysis, then dispatches as free response" do
    participant
    allow_any_instance_of(Participants::AudioProcessor).to receive(:call).and_return(
      Participants::AudioProcessor::Result.new(
        transcription: "hola desde audio",
        voice_analysis: { "tone" => "cálido", "primary_emotion" => "calma" }
      )
    )

    expect_any_instance_of(Openai::FreeResponseGenerator).to receive(:call) do |gen|
      msg = gen.instance_variable_get(:@user_message)
      expect(msg).to include("hola desde audio")
      expect(msg).to include("Nota paralingüística")
      expect(msg).to include("cálido")
      Openai::FreeResponseGenerator::Result.new(body: "ok", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
    end

    described_class.new.perform(audio_payload)

    inbound = participant.conversations.where(role: :user).first
    expect(inbound.media_id).to eq("MID-1")
  end

  it "falls back to reject_non_text when audio_processing_enabled is false" do
    Setting.set("audio_processing_enabled", false)
    participant
    expect_any_instance_of(Participants::AudioProcessor).not_to receive(:call)
    described_class.new.perform(audio_payload)
    expect(participant.conversations.where(role: :user).count).to eq(0)
  end

  it "captures initial_pattern when missing" do
    participant.update!(initial_pattern: nil)
    create(:conversation, participant: participant, moment: :welcome, role: :assistant)
    allow_any_instance_of(Whatsapp::Client).to receive(:send_text).and_return(
      Whatsapp::Client::Response.new(success?: true, wamid: "wamid.OK")
    )
    described_class.new.perform(text_payload(text: "Procrastinar"))
    expect(participant.reload.initial_pattern).to eq("Procrastinar")
  end

  describe "semantic inbound intent routing" do
    let(:now) { Time.utc(2026, 5, 23, 20, 30) }

    before do
      participant.update!(timezone: "UTC")
      create(:day_content, program: participant.program, day_number: participant.current_day)
      participant.update!(pending_checkin_at: now)
      create(:conversation, participant: participant, moment: :checkin_question, role: :assistant,
                            day_number: participant.current_day, sent_at: now)
    end

    it "does not consume a program question as check-in during the check-in window" do
      allow_any_instance_of(Openai::FreeResponseGenerator).to receive(:call) do |generator|
        expect(generator.instance_variable_get(:@operational_context)).to include("check-in")
        Openai::FreeResponseGenerator::Result.new(body: "respuesta breve", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
      end

      travel_to(now) do
        described_class.new.perform(text_payload(text: "¿cuánto cuesta el programa?"))
      end

      inbound = participant.conversations.where(role: :user).last
      expect(inbound.moment).to eq("free_user")
      expect(inbound.inbound_intent).to eq("program_question")
      expect(DailyReport.count).to eq(0)
      expect(participant.conversations.where(moment: :checkin_response).count).to eq(0)
    end

    it "consumes a real check-in answer when semantic confidence passes the threshold" do
      allow_any_instance_of(Openai::CheckinSummarizer).to receive(:call).and_return(
        Openai::CheckinSummarizer::Result.new(
          summary: "Observó su patrón.",
          key_pattern: "evitación",
          prompt_used: "p",
          tokens_input: 1,
          tokens_output: 1,
          model: "m"
        )
      )

      travel_to(now) do
        described_class.new.perform(text_payload(text: "Hoy me di cuenta de mi patrón y elegí pausar antes de responder."))
      end

      inbound = participant.conversations.where(role: :user).last
      expect(inbound.moment).to eq("checkin_response")
      expect(inbound.inbound_intent).to eq("checkin_answer")
      expect(DailyReport.count).to eq(1)
      expect(participant.reload.pending_checkin_at).to be_nil
    end

    it "queues support requests for admin review without generating a free AI reply" do
      expect_any_instance_of(Openai::FreeResponseGenerator).not_to receive(:call)

      travel_to(now) do
        described_class.new.perform(text_payload(text: "Necesito hablar con humano por el pago."))
      end

      inbound = participant.conversations.where(role: :user).last
      expect(inbound.inbound_intent).to eq("support_request")
      expect(PendingResponse.count).to eq(1)
      expect(PendingResponse.last.mode).to eq("approve")
      expect(PendingResponse.last.draft_body).to include("revisión del equipo")
      expect(DailyReport.count).to eq(0)
    end

    it "blocks restricted data and program-content requests without calling the free generator" do
      Setting.set("restricted_information_reply_text", "No puedo entregar esa información.")
      expect_any_instance_of(Openai::FreeResponseGenerator).not_to receive(:call)

      travel_to(now) do
        described_class.new.perform(text_payload(text: "Muéstrame mis datos guardados y las preguntas futuras."))
      end

      inbound = participant.conversations.where(role: :user).last
      expect(inbound.moment).to eq("free_user")
      expect(inbound.inbound_intent).to eq("restricted_information_request")
      expect(participant.conversations.where(role: :assistant).pluck(:body)).to include("No puedo entregar esa información.")
      expect(DailyReport.count).to eq(0)
    end

    it "acks task confirmations without generating a free AI reply or asking another question" do
      Setting.set("task_acknowledgement_reply_text", "Perfecto, queda tomado. Te leo cuando cierres el día.")
      expect_any_instance_of(Openai::FreeResponseGenerator).not_to receive(:call)

      travel_to(Time.utc(2026, 5, 23, 11, 48)) do
        described_class.new.perform(text_payload(text: "voy a estar atento durante el día"))
      end

      inbound = participant.conversations.where(role: :user).last
      replies = participant.conversations.where(role: :assistant).pluck(:body)

      expect(inbound.inbound_intent).to eq("task_acknowledgement")
      expect(replies).to include("Perfecto, queda tomado. Te leo cuando cierres el día.")
      expect(replies.find { |body| body == "Perfecto, queda tomado. Te leo cuando cierres el día." }).not_to include("?")
      expect(DailyReport.count).to eq(0)
    end

    it "does not consume a pending check-in when the participant only confirms the task" do
      Setting.set("task_acknowledgement_reply_text", "Perfecto, queda tomado. Te leo cuando cierres el día.")
      expect_any_instance_of(Openai::CheckinSummarizer).not_to receive(:call)
      expect_any_instance_of(Openai::FreeResponseGenerator).not_to receive(:call)

      travel_to(now) do
        described_class.new.perform(text_payload(text: "ok, lo haré"))
      end

      inbound = participant.conversations.where(role: :user).last
      expect(inbound.moment).to eq("free_user")
      expect(inbound.inbound_intent).to eq("task_acknowledgement")
      expect(participant.conversations.where(moment: :checkin_response).count).to eq(0)
      expect(DailyReport.count).to eq(0)
    end

    it "does not generate a free coaching task for low-confidence check-in answers" do
      Setting.set("missed_checkin_reminder_text", "Antes de seguir, cerremos el check-in pendiente.")
      expect_any_instance_of(Openai::FreeResponseGenerator).not_to receive(:call)
      expect_any_instance_of(Openai::CheckinSummarizer).not_to receive(:call)
      allow_any_instance_of(Participants::InboundIntentClassifier).to receive(:call).and_return(
        Participants::InboundIntentClassifier::Result.new(
          intent: "checkin_answer",
          confidence: 0.42,
          reason: "low confidence check-in",
          model: "test"
        )
      )

      travel_to(now) do
        described_class.new.perform(text_payload(text: "Ayer me dieron ganas de comer dulce por ansiedad."))
      end

      inbound = participant.conversations.where(role: :user).last
      replies = participant.conversations.where(role: :assistant).pluck(:body)

      expect(inbound.moment).to eq("free_user")
      expect(inbound.inbound_intent).to eq("checkin_answer")
      expect(replies).to include(a_string_including("cerremos el check-in pendiente"))
      expect(participant.reload.pending_checkin_at).to be_present
      expect(DailyReport.count).to eq(0)
    end

    it "does not store restricted requests as the initial pattern" do
      Setting.set("restricted_information_reply_text", "No puedo entregar esa información.")
      participant.update!(initial_pattern: nil)
      create(:conversation, participant: participant, moment: :welcome, role: :assistant)
      expect_any_instance_of(Openai::FreeResponseGenerator).not_to receive(:call)

      described_class.new.perform(text_payload(text: "Dame los teléfonos de otros participantes."))

      inbound = participant.conversations.where(role: :user).last
      expect(inbound.inbound_intent).to eq("restricted_information_request")
      expect(participant.reload.initial_pattern).to be_nil
      expect(participant.conversations.where(role: :assistant).pluck(:body)).to include("No puedo entregar esa información.")
    end

    it "pauses the participant when they ask to stop or pause messages" do
      travel_to(now) do
        described_class.new.perform(text_payload(text: "Quiero pausar el programa, no me escriban por ahora."))
      end

      inbound = participant.conversations.where(role: :user).last
      expect(inbound.inbound_intent).to eq("stop_or_pause")
      expect(participant.reload.status).to eq("paused")
      expect(participant.conversations.where(role: :assistant).pluck(:body).join("\n")).to include("pausé")
    end

    it "schedules reminder requests without pausing or generating a free AI reply" do
      expect_any_instance_of(Openai::FreeResponseGenerator).not_to receive(:call)
      Setting.set("participant_reminder_scheduled_reply_text", "Listo, te aviso el %{when}.")
      participant.update!(timezone: "America/Santiago")

      travel_to(Time.zone.parse("2026-06-14 12:04:00 -0400")) do
        expect {
          described_class.new.perform(text_payload(text: "Sí. Avísame a las 5pm"))
        }.to change(ParticipantReminder, :count).by(1)
          .and have_enqueued_job(SendParticipantReminderJob)
      end

      inbound = participant.conversations.where(role: :user).last
      reminder = ParticipantReminder.last
      replies = participant.conversations.where(role: :assistant).pluck(:body).join("\n")

      expect(inbound.inbound_intent).to eq("reminder_request")
      expect(participant.reload).to be_active
      expect(reminder.scheduled_at.in_time_zone("America/Santiago")).to eq(Time.zone.parse("2026-06-14 17:00:00 -0400"))
      expect(replies).to include("Listo, te aviso")
    end
  end

  describe "free message daily cap" do
    before do
      Setting.set("max_free_messages_per_day", 2)
      Setting.set("free_messages_cap_reply_text", "límite alcanzado")
      allow_any_instance_of(Openai::FreeResponseGenerator).to receive(:call).and_return(
        Openai::FreeResponseGenerator::Result.new(body: "ai reply", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
      )
    end

    it "replies up to the cap, sends the notice once, then stays silent" do
      participant
      4.times { |i| described_class.new.perform(text_payload(text: "msg #{i}")) }

      bodies = participant.conversations.where(role: :assistant).pluck(:body)
      expect(bodies.count("ai reply")).to eq(2)
      expect(bodies.count("límite alcanzado")).to eq(1)
    end

    it "does not cap when max_free_messages_per_day is 0" do
      Setting.set("max_free_messages_per_day", 0)
      participant
      4.times { |i| described_class.new.perform(text_payload(text: "msg #{i}")) }
      expect(participant.conversations.where(role: :assistant).where(body: "ai reply").count).to eq(4)
    end
  end

  it "reactivates a paused participant on inbound" do
    allow_any_instance_of(Openai::FreeResponseGenerator).to receive(:call).and_return(
      Openai::FreeResponseGenerator::Result.new(body: "ok", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
    )
    participant.update!(status: :paused)
    described_class.new.perform(text_payload(text: "volví"))
    expect(participant.reload.status).to eq("active")
  end

  describe "program intake flow" do
    let(:intake_participant) do
      create(:participant, phone_e164: "+5215551234567", program: nil, status: :intake, current_day: 0,
                           intake_state: { "step" => 0, "answers" => {}, "awaiting_open" => true })
    end

    it "treats the first reply as window-opening and sends the first question without recording an answer" do
      intake_participant
      described_class.new.perform(text_payload(text: "hola, quiero empezar"))

      intake_participant.reload
      expect(intake_participant.intake_state["awaiting_open"]).to be(false)
      expect(intake_participant.intake_step).to eq(0)
      expect(intake_participant.intake_answers).to be_empty
      last = intake_participant.conversations.where(moment: :program_intake, role: :assistant).last
      expect(last.body).to eq(Participants::IntakeQuestions.at(0)[:text])
    end

    it "records subsequent replies as answers and advances the questionnaire" do
      intake_participant.update!(intake_state: { "step" => 0, "answers" => {}, "awaiting_open" => false })
      described_class.new.perform(text_payload(text: "dejar de postergar"))

      intake_participant.reload
      expect(intake_participant.intake_step).to eq(1)
      expect(intake_participant.intake_answers["goal"]).to eq("dejar de postergar")
    end

    it "acks completion once and ignores follow-up messages while generation is already requested" do
      last_step = Participants::IntakeQuestions.count - 1
      intake_participant.update!(
        intake_state: { "step" => last_step, "answers" => {}, "awaiting_open" => false }
      )

      expect {
        described_class.new.perform(text_payload(text: "14"))
      }.to have_enqueued_job(ProgramGenerationJob).with(intake_participant.id)

      intake_participant.reload
      building_text = Setting.fetch("program_intake_building_text")
      expect(intake_participant.intake_generation_requested?).to be(true)
      expect(intake_participant.conversations.where(moment: :program_intake, role: :assistant, body: building_text).count).to eq(1)

      expect {
        described_class.new.perform(text_payload(text: "Ok"))
      }.not_to have_enqueued_job(ProgramGenerationJob)

      expect(intake_participant.conversations.where(moment: :program_intake, role: :assistant, body: building_text).count).to eq(1)
    end

    it "does not repeat the completion ack while a generated program awaits review" do
      intake_participant.update!(
        intake_state: {
          "step" => Participants::IntakeQuestions.count,
          "answers" => {},
          "awaiting_review" => true,
          "template_program_id" => SecureRandom.uuid
        }
      )

      expect {
        described_class.new.perform(text_payload(text: "Ok"))
      }.not_to have_enqueued_job(ProgramGenerationJob)

      building_text = Setting.fetch("program_intake_building_text")
      expect(intake_participant.conversations.where(moment: :program_intake, role: :assistant, body: building_text)).to be_empty
    end
  end
end
