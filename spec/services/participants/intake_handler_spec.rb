require "rails_helper"

RSpec.describe Participants::IntakeHandler do
  let(:participant) do
    create(:participant, status: :intake, program: nil, current_day: 0,
                         intake_state: { "step" => 0, "answers" => {} })
  end

  it "records the answer for the current step and reports the next question" do
    result = described_class.new(participant: participant, answer_text: "dejar de postergar").call

    participant.reload
    expect(participant.intake_step).to eq(1)
    expect(participant.intake_answers).to eq("goal" => "dejar de postergar")
    expect(result).not_to be_complete
    expect(result.next_question).to eq(Participants::IntakeQuestions.at(1)[:text])
  end

  it "reports completion after the last question is answered" do
    last = Participants::IntakeQuestions.count - 1
    participant.update!(intake_state: { "step" => last, "answers" => {} })

    result = described_class.new(participant: participant, answer_text: "21 días").call

    expect(result).to be_complete
    expect(result.next_question).to be_nil
    expect(participant.reload.intake_answers["duration"]).to eq("21 días")
  end

  it "is a no-op when the questionnaire is already past the last step" do
    participant.update!(intake_state: { "step" => 99, "answers" => { "goal" => "x" } })

    result = described_class.new(participant: participant, answer_text: "extra").call

    expect(result).to be_complete
    expect(participant.reload.intake_answers).to eq("goal" => "x")
  end
end
