class SendIntakeQuestionJob < ApplicationJob
  queue_as :default

  # Sends the intake question for the participant's current step. Used to kick off
  # the questionnaire (step 0); subsequent questions are sent inline by
  # ProcessIncomingMessageJob as each answer arrives. Idempotent: skips if that exact
  # question was already sent.
  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    return unless participant.intake?

    question = Participants::IntakeQuestions.at(participant.intake_step)
    return if question.nil?
    return if already_sent?(participant, question[:text])

    Outbound::Dispatcher.new(
      participant: participant, moment: :program_intake, day_number: 0
    ).send_text(body: question[:text])
  end

  private

  def already_sent?(participant, text)
    participant.conversations.kept
               .where(moment: :program_intake, role: :assistant, body: text)
               .where.not(sent_at: nil)
               .exists?
  end
end
