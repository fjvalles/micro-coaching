class AddProgramToPromptExecutions < ActiveRecord::Migration[7.2]
  def up
    add_reference :prompt_executions, :program, type: :uuid, foreign_key: true, index: true
    add_column :prompt_executions, :billable_seconds, :integer

    execute <<~SQL.squish
      UPDATE prompt_executions pe
      SET program_id = COALESCE(
        (SELECT pt.program_id FROM prompt_templates pt WHERE pt.id = pe.prompt_template_id),
        (SELECT p.program_id FROM participants p WHERE p.id = pe.participant_id)
      )
      WHERE pe.program_id IS NULL
    SQL
  end

  def down
    remove_column :prompt_executions, :billable_seconds
    remove_reference :prompt_executions, :program, foreign_key: true
  end
end
