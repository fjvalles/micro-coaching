class AddProgramToParticipantsAndDayContents < ActiveRecord::Migration[7.2]
  def change
    add_reference :participants,  :program, type: :uuid, null: true, foreign_key: true
    add_reference :day_contents,  :program, type: :uuid, null: true, foreign_key: true

    remove_index :day_contents, :day_number
    add_index :day_contents, %i[program_id day_number], unique: true, name: "index_day_contents_on_program_id_and_day_number"
  end
end
