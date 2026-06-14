class PaymentsController < ApplicationController
  layout "landing"

  # Webpay posts back on abort/timeout without a CSRF token.
  skip_before_action :verify_authenticity_token, only: :commit

  def new
    @participant = Participant.kept.find_by(id: params[:participant_id])
    @program = resolve_program(@participant)
    @price = price_for(@participant, @program)
    @enabled = Setting.fetch("webpay_enabled") && @price.positive?
    @founder = @participant&.nivel2_offer_active? || false
  end

  def create
    participant = Participant.kept.find_by(id: params[:participant_id])
    program = resolve_program(participant)
    price = price_for(participant, program)
    unless Setting.fetch("webpay_enabled") && price.positive?
      redirect_to pagos_path(participant_id: participant&.id), alert: "Los pagos no están habilitados en este momento." and return
    end

    payment = Payment.create!(
      participant: participant,
      company: participant&.company,
      program: program,
      amount: price,
      purpose: program&.paid? ? :personalized : :membership,
      founder_bonus: participant&.nivel2_offer_active? || false,
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
      redirect_to pagos_path(participant_id: participant&.id), alert: "No se pudo iniciar el pago. Intenta nuevamente."
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
      fulfill(payment)
      @status = :authorized
    elsif result.success?
      payment.update!(status: :rejected, response_code: result.response_code, raw_response: result.raw)
      @status = :rejected
    else
      payment.update!(status: :failed, raw_response: { error: result.error })
      @status = :failed
    end
  end

  # Routes a successful charge to the right fulfillment: door-pay activates the
  # participant; a personalized Nivel 2 unlock re-enrolls them onto the reviewed
  # template via Programs::Approver.
  def fulfill(payment)
    if payment.personalized?
      reenroll_personalized(payment)
    else
      activate_participant(payment.participant)
    end
  end

  # Payment-gated enroll: a successful first charge activates the participant and
  # fires the welcome (idempotent — no-op if they were already active).
  def activate_participant(participant)
    return unless participant&.awaiting_payment?

    Participants::Activator.new(participant).call
  end

  # Day-14 unlock: the participant paid for the personalized program they designed.
  # payment.program is the reviewed TEMPLATE; Approver clones it and re-enrolls the
  # completed participant onto the live copy. Idempotent (Approver no-ops if active).
  def reenroll_personalized(payment)
    participant = payment.participant
    template = payment.program
    return unless participant && template&.template?
    # Tamper guard: must match the template this participant actually had generated.
    return unless participant.intake_state["template_program_id"].to_s == template.id.to_s

    Programs::Approver.new(participant: participant, template: template).call
    participant.update!(nivel2_offer_sent_at: nil)
  end

  # Resolves the program being paid for: an explicit program_id (the reviewed Nivel 2
  # template) or the participant's current program (legacy door-pay).
  def resolve_program(participant)
    if params[:program_id].present?
      Program.find_by(id: params[:program_id])
    else
      participant&.program
    end
  end

  # Paid programs use their own price (founder price inside the day-14 window);
  # legacy door-pay uses the global membership price.
  def price_for(participant, program)
    if program&.paid?
      return 0 if participant.nil?

      program.effective_price_clp(within_founder_window: participant.nivel2_offer_active?)
    else
      # Legacy door-pay (public /pagos with no participant or a free program).
      Setting.fetch("membership_price_clp").to_i
    end
  end
end
