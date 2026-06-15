require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    let!(:program) { create(:program) }

    it "renders the landing page successfully" do
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Impulso by Comtraining")
      expect(response.body).to include("Reservar mi cupo").or include("Solicitar mi cupo")
      expect(response.body).to include("Cupos de lanzamiento")
      expect(response.body).to include("garantía clara")
      expect(response.body).to include("micro-desafío")
      expect(response.body).to include("¿Te tinca?")
      expect(response.body).not_to include("¿Te late?")
      expect(response.body).not_to include("Empieza gratis")
      expect(response.body).not_to include("prueba gratis")
      expect(response.body).not_to include("fundador")
    end
  end

  describe "POST /preview_challenge" do
    context "with blank goal" do
      it "returns unprocessable entity" do
        post preview_challenge_path, params: { goal: "" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to have_key("error")
      end
    end

    context "with valid goal" do
      let(:openai_result) do
        Openai::Client::Result.new(
          content: "Hola. Tu desafío de hoy es meditar 5 minutos.",
          tokens_input: 50,
          tokens_output: 30,
          model: "gpt-4.1-mini"
        )
      end

      before do
        allow_any_instance_of(Openai::Client).to receive(:chat) do |_client, args|
          prompt = args[:messages].first[:content]
          expect(prompt).to include("español chileno natural")
          expect(prompt).to include("te late")
          openai_result
        end
      end

      it "returns the simulated challenge as json" do
        post preview_challenge_path, params: { goal: "Meditar por la mañana" }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["challenge"]).to include("meditar 5 minutos")
      end
    end

    context "when OpenAI raises an error" do
      before do
        allow_any_instance_of(Openai::Client).to receive(:chat).and_raise("OpenAI connection timed out")
      end

      it "returns a 500 error" do
        post preview_challenge_path, params: { goal: "Correr 5k" }
        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)["error"]).to include("Hubo un error")
      end
    end
  end

  describe "POST /enroll" do
    let!(:program) { create(:program) }

    context "with missing parameters" do
      it "redirects with flash alert when name is missing" do
        post enroll_path, params: { name: "", phone: "+56912345678", email: "carlos@example.com" }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("obligatorios")
      end

      it "redirects with flash alert when phone is missing" do
        post enroll_path, params: { name: "Carlos", phone: "", email: "carlos@example.com" }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("obligatorios")
      end

      it "redirects with flash alert when email is missing" do
        post enroll_path, params: { name: "Carlos", phone: "+56912345678", email: "" }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("obligatorios")
      end
    end

    context "with invalid phone numbers" do
      it "rejects phone numbers that don't match E.164 pattern" do
        post enroll_path, params: { name: "Carlos", phone: "abc1234", email: "carlos@example.com" }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("formato internacional")
      end
    end

    context "with valid parameters" do
      let(:phone) { "+56912345678" }

      it "creates a new participant, schedules welcome job, and renders success" do
        expect {
          post enroll_path, params: {
            name: "Carlos",
            phone: phone,
            timezone: "America/Santiago",
            company: "Comtraining S.A.",
            role: "Gerente RRHH",
            email: "carlos@comtraining.com"
          }
        }.to change(Participant, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Inscripción Exitosa")
        expect(response.body).to include("Carlos")

        participant = Participant.order(:created_at).last
        expect(participant.phone_e164).to eq(phone)
        expect(participant.name).to eq("Carlos")
        expect(participant.timezone).to eq("America/Santiago")
        expect(participant.status).to eq("active")
        expect(participant[:company]).to eq("Comtraining S.A.") # public enroll stores the legacy string column
        expect(participant.role).to eq("Gerente RRHH")
        expect(participant.email).to eq("carlos@comtraining.com")
      end

      it "renders a dialable wa.me link, not the Meta phone-number-id" do
        post enroll_path, params: { name: "Carlos", phone: phone, email: "carlos@example.com" }

        expect(response.body).to include("https://wa.me/56957463136")
      end

      it "logs the new sign-up into their portal session" do
        post enroll_path, params: { name: "Carlos", phone: phone, email: "carlos@example.com" }

        # Auto-login: the just-created participant can reach their portal without a magic link.
        get portal_root_path
        expect(response).to have_http_status(:ok)
      end

      it "automatically cleans phone formatting spacing and prepends + if missing" do
        post enroll_path, params: {
          name: "Carlos",
          phone: " 56 9 1234-5678 ",
          email: "carlos@example.com",
          timezone: "America/Santiago"
        }
        expect(response).to have_http_status(:ok)
        participant = Participant.order(:created_at).last
        expect(participant.phone_e164).to eq("+56912345678")
      end

      it "rejects duplicate enrollments for undiscarded participants" do
        create(:participant, phone_e164: "+56912345678", program: program)

        expect {
          post enroll_path, params: { name: "Carlos Nuevo", phone: "+56912345678", email: "nuevo@example.com" }
        }.not_to change(Participant, :count)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("ya está registrado")
      end

      it "redirects an individual to payment when membership is charged" do
        Setting.set("webpay_enabled", true)
        Setting.set("membership_price_clp", 15_000)

        post enroll_path, params: {
          name: "Paga",
          phone: "+56999998888",
          email: "paga@example.com",
          timezone: "America/Santiago"
        }

        participant = Participant.order(:created_at).last
        expect(participant.status).to eq("awaiting_payment")
        expect(response).to redirect_to(pagos_path(participant_id: participant.id))
      end
    end
  end

  describe "GET /privacidad" do
    before do
      Setting.set("privacy_policy", "Esta es la politica de prueba para Comtraining.")
    end

    it "renders the privacy page successfully and includes the policy text" do
      get privacidad_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Política de Privacidad")
      expect(response.body).to include("politica de prueba")
    end
  end
end
