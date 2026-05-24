class PendingResponseMailer < ApplicationMailer
  def new_pending(pending_response_id)
    @pending = PendingResponse.find(pending_response_id)
    @participant = @pending.participant
    recipient = AdminUser.first&.email
    return if recipient.blank?

    mail(to: recipient, subject: "Respuesta pendiente: #{@participant.name} (#{@pending.moment})")
  end
end
