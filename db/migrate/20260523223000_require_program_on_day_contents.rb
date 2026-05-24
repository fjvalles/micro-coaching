class RequireProgramOnDayContents < ActiveRecord::Migration[7.2]
  class DayContent < ApplicationRecord
    self.table_name = "day_contents"
  end

  def up
    if DayContent.where(program_id: nil).exists?
      raise ActiveRecord::IrreversibleMigration, "Cannot require program_id while day contents without program exist"
    end

    change_column_null :day_contents, :program_id, false
  end

  def down
    change_column_null :day_contents, :program_id, true
  end
end
