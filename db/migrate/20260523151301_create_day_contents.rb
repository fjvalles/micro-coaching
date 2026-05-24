class CreateDayContents < ActiveRecord::Migration[7.2]
  def change
    create_table :day_contents, id: :uuid do |t|
      t.integer :day_number, null: false
      t.integer :phase, null: false
      t.string :title, null: false
      t.text :morning_template
      t.text :iareto_text
      t.text :checkin_questions
      t.text :ai_system_prompt
      t.string :template_name_whatsapp
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :day_contents, :day_number, unique: true
  end
end
