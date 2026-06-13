class AddNextProgramToPrograms < ActiveRecord::Migration[7.2]
  def change
    # Self-referential chain: completing this program can offer/transition the
    # participant into next_program (e.g. "Nivel 1" → "Nivel 2"). Nil = no next.
    add_reference :programs, :next_program, type: :uuid, null: true,
                  foreign_key: { to_table: :programs }
  end
end
