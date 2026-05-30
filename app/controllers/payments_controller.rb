class PaymentsController < ApplicationController
  layout "landing"

  # Webpay posts back on abort/timeout without a CSRF token.
  skip_before_action :verify_authenticity_token, only: :commit

  def new
    @participant = Participant.kept.find_by(id: params[:participant_id])
    @price = Setting.fetch("membership_price_clp").to_i
    @enabled = Setting.fetch("webpay_enabled") && @price.positive?
  end

  def create
    price = Setting.fetch("membership_price_clp").to_i
    unless Setting.fetch("webpay_enabled") && price.positive?
      redirect_to pagos_path, alert: "Los pagos no están habilitados en este momento." and return
    end

    participant = Participant.kept.find_by(id: params[:participant_id])
    payment = Payment.create!(
      participant: participant,
      company: participant&.company,
      program: participant&.program,
      amount: price,
      buy_order: Payment.next_buy_order,
      session_id: SecureRandom.hex(8),
      status: :pending
    )

    result = Webpay::Client.new.create(
      buy_order: payment.buy_order,
      session_id: payment.session_id,
      amount: price,
      return_url: pago_retorno_url
    )

    if result.success?
      payment.update!(token: result.token)
      redirect_to "#{result.url}?token_ws=#{result.token}", allow_other_host: true
    else
      payment.update!(status: :failed, raw_response: { error: result.error })
      redirect_to pagos_path, alert: "No se pudo iniciar el pago. Intenta nuevamente."
    end
  end

  # Webpay return. token_ws = normal flow; TBK_TOKEN present = user aborted the form.
  def commit
    if params[:TBK_TOKEN].present?
      Payment.find_by(token: params[:TBK_TOKEN])&.update(status: :aborted)
      @status = :aborted
      return render :result
    end

    token = params[:token_ws].to_s
    @payment = Payment.find_by(token: token) if token.present?

    if @payment.nil?
      @status = :unknown
      return render :result
    end

    # Idempotent: a refresh / double return should not re-commit.
    if @payment.authorized? || @payment.rejected?
      @status = @payment.status.to_sym
      return render :result
    end

    finalize(@payment, token)
    render :result
  end

  private

  def finalize(payment, token)
    result = Webpay::Client.new.commit(token: token)

    if result.success? && result.authorized
      payment.assign_commission_snapshot!
      payment.assign_attributes(
        status: :authorized,
        paid_at: Time.current,
        authorization_code: result.authorization_code,
        payment_type_code: result.payment_type_code,
        response_code: result.response_code,
        installments: result.installments,
        card_last4: result.card_last4.to_s.last(4),
        raw_response: result.raw
      )
      payment.save!
      @status = :authorized
    elsif result.success?
      payment.update!(status: :rejected, response_code: result.response_code, raw_response: result.raw)
      @status = :rejected
    else
      payment.update!(status: :failed, raw_response: { error: result.error })
      @status = :failed
    end
  end
end
