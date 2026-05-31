require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  before do
    Setting.set("webpay_oneclick_enabled", true)
    Setting.set("subscription_price_clp", 15_000)
    Setting.set("subscription_billing_interval_days", 30)
    Setting.set("tax_rate", 0.19)
    Setting.set("payment_commission_rate", 0.0149)
  end

  describe "GET /suscripcion" do
    it "renders the subscription page with the price" do
      get suscripcion_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Suscripción")
      expect(response.body).to include("15.000")
    end
  end

  describe "POST /suscripcion" do
    it "creates a pending subscription and redirects to Webpay" do
      allow_any_instance_of(Webpay::OneclickClient).to receive(:start_inscription).and_return(
        Webpay::OneclickClient::StartResult.new(success: true, token: "tok", url: "https://wp/oc")
      )

      expect { post suscripcion_path }.to change(Subscription, :count).by(1)
      expect(response).to redirect_to("https://wp/oc?TBK_TOKEN=tok")
    end

    it "redirects back when subscriptions are disabled" do
      Setting.set("webpay_oneclick_enabled", false)

      expect { post suscripcion_path }.not_to change(Subscription, :count)
      expect(response).to redirect_to(suscripcion_path)
    end
  end

  describe "GET /suscripcion/retorno" do
    it "finishes inscription, charges, and activates the subscription + participant" do
      participant = create(:participant, status: :awaiting_payment, current_day: 0, started_at: nil)

      allow_any_instance_of(Webpay::OneclickClient).to receive(:start_inscription).and_return(
        Webpay::OneclickClient::StartResult.new(success: true, token: "tok", url: "https://wp/oc")
      )
      post suscripcion_path, params: { participant_id: participant.id }

      allow_any_instance_of(Webpay::OneclickClient).to receive(:finish_inscription).and_return(
        Webpay::OneclickClient::FinishResult.new(success: true, tbk_user: "tbk-1", card_last4: "1111", response_code: 0)
      )
      allow_any_instance_of(Webpay::OneclickClient).to receive(:charge).and_return(
        Webpay::OneclickClient::ChargeResult.new(
          success: true, authorized: true, status: "AUTHORIZED", amount: 15_000,
          authorization_code: "A", payment_type_code: "VN", response_code: 0, installments: 0, raw: {}
        )
      )
      expect(SendWelcomeJob).to receive(:perform_later).with(participant.id)

      expect {
        get suscripcion_retorno_path, params: { TBK_TOKEN: "tok" }
      }.to change(Payment, :count).by(1)

      expect(response).to have_http_status(:ok)
      subscription = Subscription.order(:created_at).last
      expect(subscription).to be_active
      expect(subscription.tbk_user).to eq("tbk-1")
      expect(participant.reload).to be_active
    end

    it "cancels the subscription when the user aborts (no token)" do
      allow_any_instance_of(Webpay::OneclickClient).to receive(:start_inscription).and_return(
        Webpay::OneclickClient::StartResult.new(success: true, token: "tok", url: "https://wp/oc")
      )
      post suscripcion_path

      get suscripcion_retorno_path
      expect(response).to have_http_status(:ok)
      expect(Subscription.order(:created_at).last).to be_canceled
    end
  end
end
