module Admin
  # Review queue for AI-generated personalized programs awaiting human approval
  # before activation. The approve action itself lives on
  # Admin::ParticipantsController#approve_program (per-participant); this index
  # collects everyone currently waiting so admins can clear them as sales scale.
  class ProgramReviewsController < BaseController
    def index
      @participants = Participant.kept
                                 .awaiting_program_review
                                 .includes(:program)
                                 .order(updated_at: :asc)
    end
  end
end
