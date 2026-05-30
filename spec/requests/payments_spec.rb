require "rails_helper"

RSpec.describe "Payments", type: :request do
  before do
    Setting.set("webpay_enabled", true)
    Setting.set("membership_price_clp", 15_000)
  end

  describe "GET /pagos" do
    it "renders the payment page with the price" do
      get pagos_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Membresía")
      expect(response.body).to include("15.000")
    end
  end

  describe "POST /pagos" do
    it "creates a pending payment and redirects to Webpay" do
      allow_any_instance_of(Webpay::Client).to receive(:create).and_return(
        Webpay::Client::CreateResult.new(success: true, token: "tok123", url: "https://wp/init")
      )
      expect { post pagos_path }.to change(Payment, :count).by(1)
      expect(response).to redirect_to("https://wp/init?token_ws=tok123")
      expect(Payment.order(:created_at).last.token).to eq("tok123")
    end

    it "redirects back when payments are disabled" do
      Setting.set("webpay_enabled", false)
      expect { post pagos_path }.not_to change(Payment, :count)
      expect(response).to redirect_to(pagos_path)
    end
  end

  describe "GET /pagos/retorno" do
    it "commits and marks the payment authorized" do
      payment = Payment.create!(amount: 15_000, buy_order: "O1", token: "tok123", status: :pending)
      allow_any_instance_of(Webpay::Client).to receive(:commit).and_return(
        Webpay::Client::CommitResult.new(
          success: true, authorized: true, status: "AUTHORIZED", amount: 15_000,
          authorization_code: "1213", payment_type_code: "VD", response_code: 0,
          installments: 0, card_last4: "6623", raw: {}
        )
      )
      get pago_retorno_path, params: { token_ws: "tok123" }
      expect(response).to have_http_status(:ok)
      expect(payment.reload).to be_authorized
      expect(payment.paid_at).to be_present
      expect(payment.net_amount).to be > 0
    end

    it "marks the payment aborted when Webpay returns TBK_TOKEN" do
      payment = Payment.create!(amount: 15_000, buy_order: "O2", token: "abc", status: :pending)
      get pago_retorno_path, params: { TBK_TOKEN: "abc" }
      expect(payment.reload).to be_aborted
    end

    it "is idempotent on a second return" do
      payment = Payment.create!(amount: 15_000, buy_order: "O3", token: "tok9", status: :authorized, paid_at: Time.current)
      expect_any_instance_of(Webpay::Client).not_to receive(:commit)
      get pago_retorno_path, params: { token_ws: "tok9" }
      expect(payment.reload).to be_authorized
    end
  end
end
