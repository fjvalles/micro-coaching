class CreateProgramAssistantSessions < ActiveRecord::Migration[7.2]
  # A chat thread between an admin and the program assistant. Holds the
  # conversation; messages and proposed actions hang off it. Used from the
  # "Asistente IA" modal on /admin/programs to create/edit/read programs.
  def change
    create_table :program_assistant_sessions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :admin_user, null: false, type: :uuid, foreign_key: true
      t.string   :title
      t.integer  :status,   null: false, default: 0 # active / archived
      t.jsonb    :metadata, null: false, default: {}
      t.integer  :tokens_input,  null: false, default: 0
      t.integer  :tokens_output, null: false, default: 0
      t.timestamps
    end

    add_index :program_assistant_sessions, [ :admin_user_id, :status ]
  end
end
