class SubscriptionsController < ApplicationController
  layout "landing"

  # Webpay posts back on the inscription return without a CSRF token.
  skip_before_action :verify_authenticity_token, only: :commit

  def new
    @participant = Participant.kept.find_by(id: params[:participant_id])
    @price   = Setting.fetch("subscription_price_clp").to_i
    @enabled = Setting.fetch("webpay_oneclick_enabled") && @price.positive?
  end

  def create
    price = Setting.fetch("subscription_price_clp").to_i
    unless Setting.fetch("webpay_oneclick_enabled") && price.positive?
      redirect_to suscripcion_path, alert: "Las suscripciones no están habilitadas en este momento." and return
    end

    participant  = Participant.kept.find_by(id: params[:participant_id])
    username     = "imp-#{SecureRandom.hex(6)}"
    subscription = Subscription.create!(
      participant: participant,
      company:     participant&.company,
      program:     participant&.program,
      amount_clp:  price,
      plan:        "monthly",
      billing_interval_days: Setting.fetch("subscription_billing_interval_days").to_i,
      tbk_username: username,
      status:      :pending
    )

    result = Webpay::OneclickClient.new.start_inscription(
      username: username, email: participant&.email.to_s, response_url: suscripcion_retorno_url
    )

    if result.success?
      session[:subscription_id] = subscription.id
      redirect_to "#{result.url}?TBK_TOKEN=#{result.token}", allow_other_host: true
    else
      subscription.update!(status: :canceled)
      redirect_to suscripcion_path, alert: "No se pudo iniciar la suscripción. Intenta nuevamente."
    end
  end

  # Inscription return: confirm the token, then run the first charge.
  def commit
    token         = params[:TBK_TOKEN].to_s
    @subscription = Subscription.find_by(id: session[:subscription_id])

    if token.blank? || @subscription.nil?
      @subscription&.update(status: :canceled)
      @status = :aborted
      return render :result
    end

    # Idempotent: a refresh after activation shouldn't re-charge.
    if @subscription.active?
      @status = :authorized
      return render :result
    end

    finish = Webpay::OneclickClient.new.finish_inscription(token: token)
    unless finish.success?
      @subscription.update!(status: :canceled)
      @status = :failed
      return render :result
    end

    @subscription.update!(tbk_user: finish.tbk_user, card_last4: finish.card_last4)
    charge_first(@subscription)
    render :result
  end

  private

  def charge_first(subscription)
    buy_order = Payment.next_buy_order
    result = Webpay::OneclickClient.new.charge(
      username:  subscription.tbk_username,
      tbk_user:  subscription.tbk_user,
      buy_order: buy_order,
      amount:    subscription.amount_clp
    )

    if result.success? && result.authorized
      @payment = subscription.record_charge!(buy_order: buy_order, result: result)
      subscription.update!(
        status: :active, started_at: Time.current,
        next_billing_at: subscription.billing_interval_days.days.from_now,
        billing_cycle_count: 1, failed_attempts: 0
      )
      Participants::Activator.new(subscription.participant).call if subscription.participant&.awaiting_payment?
      @status = :authorized
    else
      subscription.update!(status: :canceled)
      @status = :rejected
    end
  end
end
