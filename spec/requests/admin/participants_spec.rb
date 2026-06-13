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
