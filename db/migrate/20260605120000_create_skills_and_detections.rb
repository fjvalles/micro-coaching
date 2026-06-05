class CreateSkillsAndDetections < ActiveRecord::Migration[7.2]
  def change
    create_table :skills, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string  :slug, null: false
      t.string  :name, null: false
      t.integer :position
      t.text    :definition
      t.text    :importance
      t.text    :trap
      t.text    :one_liner
      t.jsonb   :signals,              null: false, default: []
      t.jsonb   :practices,            null: false, default: []
      t.jsonb   :gestures,             null: false, default: []
      t.jsonb   :exercises,            null: false, default: []
      t.jsonb   :reflection_questions, null: false, default: []
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :skills, :slug, unique: true
    add_index :skills, :position

    create_table :skill_detections, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :participant,  null: false, type: :uuid, foreign_key: true
      t.references :conversation, null: false, type: :uuid, foreign_key: true
      t.references :skill,        null: false, type: :uuid, foreign_key: true
      t.float      :confidence
      t.string     :source
      t.datetime   :detected_at, null: false
      t.timestamps
    end
    add_index :skill_detections, [ :participant_id, :detected_at ], order: { detected_at: :desc }
    add_index :skill_detections, [ :conversation_id, :skill_id ], unique: true
  end
end
