class AddAudioFieldsToConversations < ActiveRecord::Migration[7.2]
  def change
    change_table :conversations, bulk: true do |t|
      t.string  :media_id
      t.string  :media_mime_type
      t.integer :audio_duration_seconds
      t.text    :transcription
      t.jsonb   :voice_analysis, default: {}, null: false
    end

    add_index :conversations, :media_id, unique: true, where: "media_id IS NOT NULL"
  end
end
