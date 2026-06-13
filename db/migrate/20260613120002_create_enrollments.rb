class CreateEnrollments < ActiveRecord::Migration[7.2]
  def change
    # Historical ledger of each program cycle a participant goes through. The live
    # state (status / current_day / program_id) stays on Participant — this table
    # records WHICH programs were run, in what order, and how each ended. Enables
    # multi-cycle journeys (Nivel 1 → Nivel 2) without refactoring core state.
    create_table :enrollments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :participant, null: false, type: :uuid, foreign_key: true
      t.references :program,     null: false, type: :uuid, foreign_key: true
      t.integer    :cycle_number, null: false, default: 1
      t.integer    :status,       null: false, default: 0 # active / completed / canceled
      t.datetime   :started_at
      t.datetime   :completed_at
      t.timestamps
    end

    add_index :enrollments, [ :participant_id, :program_id, :cycle_number ],
              unique: true, name: "index_enrollments_on_participant_program_cycle"
    add_index :enrollments, [ :participant_id, :status ]
  end
end
