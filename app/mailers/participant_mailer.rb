class ParticipantMailer < ApplicationMailer
  def magic_link(participant_id, token)
    @participant = Participant.find(participant_id)
    return if @participant.email.blank?

    @url = portal_session_url(token)
    mail(to: @participant.email, subject: "Tu acceso a Impulso")
  end
end
