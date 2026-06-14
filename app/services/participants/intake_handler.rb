module Participants
  # Advances the WhatsApp intake questionnaire by one answer.
  #
  # Stateless across calls except for participant.intake_state, which holds the
  # authoritative step index. Each call records the answer for the current step,
  # bumps the step, and reports the next question (or completion). Sending the
  # next message / kicking off generation is the caller's job (ProcessIncomingMessageJob).
  #
  # Idempotency: the step lives in intake_state, so a replayed inbound only advances
  # if it carries a new answer. The job creates exactly one inbound Conversation per
  # message before calling this, so double-processing the same wamid is prevented upstream.
  class IntakeHandler
    Result = Struct.new(:next_question, :complete, keyword_init: true) do
      def complete? = complete
    end

    def initialize(participant:, answer_text:)
      @participant = participant
      @answer_text = answer_text.to_s.strip
    end

    def call
      step = @participant.intake_step
      question = Participants::IntakeQuestions.at(step)

      # Already past the questionnaire (e.g. awaiting review) — nothing to record.
      return Result.new(next_question: nil, complete: true) if question.nil?

      record_answer(question, step)

      next_step = step + 1
      next_question = Participants::IntakeQuestions.at(next_step)
      Result.new(next_question: next_question&.fetch(:text), complete: next_question.nil?)
    end

    private

    def record_answer(question, step)
      answers = @participant.intake_answers.merge(question[:key] => @answer_text)
      PaperTrail.request(whodunnit: "ai:IntakeHandler", controller_info: { source: "ai" }) do
        @participant.update!(
          intake_state: @participant.intake_state.merge(
            "answers" => answers,
            "step" => step + 1
          )
        )
      end
    end
  end
end
