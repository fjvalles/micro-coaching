class AddProgramIntake < ActiveRecord::Migration[7.2]
  def change
    # Per-participant intake state machine: { "step" => 2, "answers" => {...}, "awaiting_review" => false }
    add_column :participants, :intake_state, :jsonb, default: {}, null: false

    # AI-authored programs: template = reusable source generated from intake answers;
    # generated marks any program produced by the generator (template or clone).
    add_column :programs, :template, :boolean, default: false, null: false
    add_column :programs, :generated, :boolean, default: false, null: false
  end
end
