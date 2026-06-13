class CreateCopilotSessions < ActiveRecord::Migration[7.2]
  # A chat thread between a superadmin and the ops copilot. Holds the
  # conversation; messages and proposed actions hang off it.
  def change
    create_table :copilot_sessions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :admin_user, null: false, type: :uuid, foreign_key: true
      t.string   :title
      t.integer  :status,   null: false, default: 0 # active / archived
      t.jsonb    :metadata, null: false, default: {}
      t.integer  :tokens_input,  null: false, default: 0
      t.integer  :tokens_output, null: false, default: 0
      t.timestamps
    end

    add_index :copilot_sessions, [ :admin_user_id, :status ]
  end
end
