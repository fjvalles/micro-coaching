class AddCoachingMemoryToParticipants < ActiveRecord::Migration[7.2]
  def change
    # coach_notes: raw, sensitive operator notes. ADMIN-ONLY — never injected into
    # any Openai:: prompt. Holds the real (potentially exposing) context.
    add_column :participants, :coach_notes, :text

    # focus_hint: abstracted, AI-safe steer ("acompañar hacia activación física").
    # Injected into the generative prompts; says where to push, not what's wrong.
    add_column :participants, :focus_hint, :text

    # ai_summary: rolling profile the AI maintains about the participant, refreshed
    # after each check-in by RefreshParticipantSummaryJob. Abstracted, AI-safe.
    add_column :participants, :ai_summary, :text
    add_column :participants, :ai_summary_updated_at, :datetime
  end
end
