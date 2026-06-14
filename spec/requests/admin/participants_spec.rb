require "rails_helper"

RSpec.describe "Admin::Participants", type: :request do
  include Warden::Test::Helpers
  include ActiveJob::TestHelper

  let(:admin) { create(:admin_user) }
  let(:program) { create(:program) }
  let!(:participant) { create(:participant, program: program, status: :pending) }

  before { login_as(admin, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /admin/participants" do
    let!(:other_program) { create(:program) }
    let!(:other_participant) { create(:participant, name: "Excluded Participant", program: other_program, status: :active, current_day: 5) }

    it "lists participants" do
      get "/admin/participants"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(participant.name)
      expect(response.body).to include(other_participant.name)
      expect(response.body).to include("Nuevo participante")
    end

    it "does not list discarded participants" do
      discarded_participant = create(:participant, program: program, name: "Discarded Person")
      discarded_participant.discard
      get "/admin/participants"
      expect(response.body).to include(participant.name)
      expect(response.body).not_to include(discarded_participant.name)
    end

    it "filters by program_id" do
      get "/admin/participants", params: { program_id: program.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(participant.name)
      expect(response.body).not_to include(other_participant.name)
    end

    it "filters by current_day" do
      get "/admin/participants", params: { current_day: 5 }
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(participant.name)
      expect(response.body).to include(other_participant.name)
    end

    it "filters by enrolled date range" do
      p_enrolled_yesterday = create(:participant, name: "Yesterday Person", program: program, enrolled_at: 1.day.ago)
      p_enrolled_tomorrow = create(:participant, name: "Tomorrow Person", program: program, enrolled_at: 1.day.from_now)

      get "/admin/participants", params: { enrolled_from: 2.days.ago.to_date.to_s, enrolled_to: Date.current.to_s }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(p_enrolled_yesterday.name)
      expect(response.body).not_to include(p_enrolled_tomorrow.name)
    end

    it "filters by company" do
      company = create(:company, name: "Comtraining")
      p_with_company = create(:participant, name: "Company Person", program: program, company: company)
      p_no_company = create(:participant, name: "No Company Person", program: program, company: nil)

      get "/admin/participants", params: { company_id: company.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(p_with_company.name)
      expect(response.body).not_to include(p_no_company.name)
    end

    it "filters by response_mode" do
      p_auto = create(:participant, name: "Auto Person", program: program, response_mode: "auto")
      p_manual = create(:participant, name: "Manual Person", program: program, response_mode: "manual")

      get "/admin/participants", params: { response_mode: "auto" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(p_auto.name)
      expect(response.body).not_to include(p_manual.name)
    end
  end

  describe "GET /admin/participants/:id" do
    it "renders the detail page" do
      get "/admin/participants/#{participant.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(participant.name)
      expect(response.body).to include(participant.phone_e164)
    end

    it "shows the review banner and approve button for a participant awaiting program review" do
      template = create(:program, name: "Reset de Mañanas", template: true, generated: true, active: false)
      awaiting = create(:participant, status: :intake, program: nil, current_day: 0,
                        intake_state: { "awaiting_review" => true, "template_program_id" => template.id })

      get "/admin/participants/#{awaiting.id}"

      expect(response.body).to include("pendiente de revisión")
      expect(response.body).to include("Reset de Mañanas")
      expect(response.body).to include(approve_program_admin_participant_path(awaiting))
    end

    it "shows the advance-to-next-program button for a completed participant with a next_program" do
      nivel2 = create(:program, name: "Nivel 2 Avanzado")
      nivel1 = create(:program, name: "Nivel 1 Base", next_program: nivel2)
      done = create(:participant, program: nivel1, status: :completed, current_day: 15)

      get "/admin/participants/#{done.id}"

      expect(response.body).to include("Avanzar a Nivel 2 Avanzado")
    end

    it "hides the advance button when the program has no next_program" do
      done = create(:participant, program: create(:program, next_program: nil), status: :completed)
      get "/admin/participants/#{done.id}"
      expect(response.body).not_to include("Avanzar a")
    end

    it "shows the immediate start button for day-one participants" do
      participant.update!(status: :active, current_day: 1)

      get "/admin/participants/#{participant.id}"

      expect(response.body).to include("Empezar programa ahora")
    end
  end

  describe "GET /admin/participants/:id/versions" do
    it "renders only fields that actually changed in the change details" do
      PaperTrail::Version.create!(
        item_type: "Participant",
        item_id: participant.id,
        event: "update",
        whodunnit: "admin@example.com",
        source: "admin",
        created_at: Time.current,
        object_changes: PaperTrail.serializer.dump(
          "name" => [ "Mismo Nombre", "Mismo Nombre" ],
          "status" => [ "pending", "active" ],
          "updated_at" => [ 1.minute.ago, Time.current ]
        )
      )

      get "/admin/participants/#{participant.id}/versions", params: { event: "update", whodunnit: "admin@example.com" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("estado:")
      expect(response.body).to include("pending")
      expect(response.body).to include("active")
      expect(response.body).not_to include("nombre:")
      expect(response.body).not_to include("updated_at")
    end
  end

  describe "GET /admin/participants/new" do
    it "renders the new form with America/Santiago default timezone" do
      get "/admin/participants/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="America/Santiago"')
    end
  end

  describe "GET /admin/participants/:id/edit" do
    it "shows the no-company option when the participant already has a company" do
      participant.update!(company: create(:company, name: "Empresa Actual"))

      get "/admin/participants/#{participant.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sin empresa (individual)")
      expect(response.body).to include("Empresa Actual")
    end
  end

  describe "POST /admin/participants" do
    it "creates a new participant" do
      expect {
        post "/admin/participants", params: {
          participant: {
            program_id: program.id,
            name: "Nuevo Test Participant",
            phone_e164: "+521999988877",
            status: "pending",
            timezone: "America/Santiago"
          }
        }
      }.to change(Participant, :count).by(1)

      new_participant = Participant.find_by(phone_e164: "+521999988877")
      expect(response).to redirect_to(admin_participant_path(new_participant))
    end

    it "starts the personalized intake when the intake program option is chosen" do
      allow(Setting).to receive(:fetch).and_call_original
      allow(Setting).to receive(:fetch).with("program_intake_enabled").and_return(true)

      expect {
        post "/admin/participants", params: {
          participant: {
            program_id: Admin::ParticipantsController::INTAKE_PROGRAM_VALUE,
            name: "Intake Test", phone_e164: "+521999900011",
            status: "pending", timezone: "America/Santiago"
          }
        }
      }.to have_enqueued_job(SendIntakeOpenerJob)

      created = Participant.find_by(phone_e164: "+521999900011")
      expect(created.program).to be_nil
      expect(created).to be_intake
      expect(flash[:notice]).to include("Intake personalizado iniciado")
    end
  end

  describe "PATCH /admin/participants/:id" do
    it "allows clearing the participant company" do
      company = create(:company)
      participant.update!(company: company)

      patch "/admin/participants/#{participant.id}", params: {
        participant: {
          company_id: "",
          name: participant.name,
          phone_e164: participant.phone_e164,
          program_id: program.id,
          status: participant.status,
          current_day: participant.current_day,
          timezone: participant.timezone
        }
      }

      expect(response).to redirect_to(admin_participant_path(participant))
      expect(participant.reload.company).to be_nil
    end
  end

  describe "POST /admin/participants/:id/enroll" do
    it "enrolls a pending participant and enqueues SendWelcomeJob" do
      expect {
        post "/admin/participants/#{participant.id}/enroll"
      }.to have_enqueued_job(SendWelcomeJob).with(participant.id)

      participant.reload
      expect(participant.status.to_sym).to eq(:active)
      expect(participant.current_day).to eq(1)
      expect(response).to redirect_to(admin_participant_path(participant))
    end
  end

  describe "POST /admin/participants/:id/start_program" do
    before do
      create(:day_content, program: program, day_number: 1)
    end

    it "starts the participant and enqueues initial program messages immediately" do
      participant.update!(status: :pending, current_day: 0, started_at: nil)

      expect {
        post "/admin/participants/#{participant.id}/start_program"
      }.to have_enqueued_job(SendWelcomeJob).with(participant.id)
        .and have_enqueued_job(MorningWakeForParticipantJob).with(participant.id)

      expect(response).to redirect_to(admin_participant_path(participant))
      expect(participant.reload).to be_active
      expect(participant.current_day).to eq(1)
      expect(flash[:notice]).to include("Programa iniciado")
    end

    it "redirects with an alert when the participant is past day one" do
      participant.update!(status: :active, current_day: 2)

      expect {
        post "/admin/participants/#{participant.id}/start_program"
      }.not_to have_enqueued_job(MorningWakeForParticipantJob)

      expect(response).to redirect_to(admin_participant_path(participant))
      expect(flash[:alert]).to include("ya pasó del día 1")
    end
  end

  describe "POST /admin/participants/:id/start_intake" do
    it "puts the participant into intake and enqueues the first question when enabled" do
      allow(Setting).to receive(:fetch).and_call_original
      allow(Setting).to receive(:fetch).with("program_intake_enabled").and_return(true)
      participant.update!(status: :pending)

      expect {
        post "/admin/participants/#{participant.id}/start_intake"
      }.to have_enqueued_job(SendIntakeOpenerJob).with(participant.id)

      expect(response).to redirect_to(admin_participant_path(participant))
      expect(participant.reload).to be_intake
      expect(flash[:notice]).to include("Intake iniciado")
    end

    it "redirects with an alert when the feature is disabled" do
      allow(Setting).to receive(:fetch).and_call_original
      allow(Setting).to receive(:fetch).with("program_intake_enabled").and_return(false)

      expect {
        post "/admin/participants/#{participant.id}/start_intake"
      }.not_to have_enqueued_job(SendIntakeOpenerJob)

      expect(flash[:alert]).to include("desactivado")
    end
  end

  describe "POST /admin/participants/:id/approve_program" do
    let(:template) do
      create(:program, template: true, generated: true, active: false, total_days: 3).tap do |p|
        create(:day_content, program: p, day_number: 1, phase: :see)
        create(:day_content, program: p, day_number: 2, phase: :choose)
        create(:day_content, program: p, day_number: 3, phase: :anchor)
      end
    end

    it "clones the awaiting-review template and activates the participant" do
      participant.update!(status: :intake, program: nil, current_day: 0,
                          intake_state: { "awaiting_review" => true, "template_program_id" => template.id,
                                          "answers" => { "pattern" => "reviso el celular" } })

      expect {
        post "/admin/participants/#{participant.id}/approve_program"
      }.to have_enqueued_job(SendWelcomeJob).with(participant.id)

      expect(response).to redirect_to(admin_participant_path(participant))
      participant.reload
      expect(participant).to be_active
      expect(participant.program.template).to be(false)
      expect(flash[:notice]).to include("aprobado")
    end

    it "redirects with an alert when there is no template to review" do
      participant.update!(status: :intake, program: nil, current_day: 0, intake_state: {})

      post "/admin/participants/#{participant.id}/approve_program"
      expect(flash[:alert]).to include("pendiente de revisión")
    end
  end

  describe "POST /admin/participants/:id/re_enroll" do
    it "advances a completed participant into the program's next_program" do
      nivel2 = create(:program, name: "Nivel 2")
      nivel1 = create(:program, name: "Nivel 1", next_program: nivel2)
      done = create(:participant, program: nivel1, status: :completed, current_day: 15)
      done.enrollments.create!(program: nivel1, cycle_number: 1, status: :completed)

      expect {
        post "/admin/participants/#{done.id}/re_enroll"
      }.to have_enqueued_job(SendWelcomeJob).with(done.id)

      done.reload
      expect(done.program).to eq(nivel2)
      expect(done.current_day).to eq(1)
      expect(done.status.to_sym).to eq(:active)
      expect(response).to redirect_to(admin_participant_path(done))
    end

    it "alerts and does nothing when there is no next_program" do
      done = create(:participant, program: create(:program, next_program: nil), status: :completed)

      post "/admin/participants/#{done.id}/re_enroll"

      expect(done.reload.status.to_sym).to eq(:completed)
      expect(response).to redirect_to(admin_participant_path(done))
      follow_redirect!
      expect(response.body).to include("no tiene un programa siguiente")
    end
  end

  describe "POST /admin/participants/:id/discard" do
    it "soft-deletes the participant" do
      post "/admin/participants/#{participant.id}/discard"
      participant.reload
      expect(participant.discarded?).to be_truthy
      expect(response).to redirect_to(admin_participant_path(participant))
    end
  end

  describe "POST /admin/participants/:id/undiscard" do
    before { participant.discard }

    it "restores the soft-deleted participant" do
      post "/admin/participants/#{participant.id}/undiscard"
      participant.reload
      expect(participant.discarded?).to be_falsey
      expect(response).to redirect_to(admin_participant_path(participant))
    end
  end

  describe "POST /admin/participants/:id/send_message" do
    let!(:active) { create(:participant, program: program, status: :active) }

    before do
      Setting.set("response_mode", "auto")
      allow_any_instance_of(Whatsapp::Client).to receive(:send_text).and_return(
        Whatsapp::Client::Response.new(success?: true, wamid: "wamid.x")
      )
      create(:conversation, participant: active, role: :user, created_at: 1.hour.ago) # open 24h window
    end

    it "sends a free-text message and redirects with a notice" do
      post "/admin/participants/#{active.id}/send_message", params: { kind: "text", body: "Hola directo" }
      expect(response).to redirect_to(admin_participant_path(active))
      expect(active.conversations.kept.where(moment: :admin_manual, body: "Hola directo")).to exist
    end

    it "redirects with an alert when out of the 24h window" do
      Conversation.delete_all
      post "/admin/participants/#{active.id}/send_message", params: { kind: "text", body: "Hola" }
      expect(flash[:alert]).to include("ventana de 24h")
    end
  end

  describe "POST /admin/participants/broadcast" do
    let!(:a) { create(:participant, program: program, status: :active) }
    let!(:b) { create(:participant, program: program, status: :active) }

    it "enqueues a BroadcastMessageJob for the selected participants" do
      expect {
        post "/admin/participants/broadcast",
             params: { participant_ids: [ a.id, b.id ], kind: "template", template_name: "bienvenida_piloto" }
      }.to have_enqueued_job(BroadcastMessageJob)
      expect(response).to redirect_to(admin_participants_path)
    end

    it "redirects with an alert when nothing is selected" do
      expect {
        post "/admin/participants/broadcast", params: { participant_ids: [], kind: "template", template_name: "t" }
      }.not_to have_enqueued_job(BroadcastMessageJob)
      expect(flash[:alert]).to be_present
    end
  end
end
