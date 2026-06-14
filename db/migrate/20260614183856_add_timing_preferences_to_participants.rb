class AddTimingPreferencesToParticipants < ActiveRecord::Migration[7.2]
  def change
    add_column :participants, :wake_hour, :integer
    add_column :participants, :checkin_hour, :integer
  end
end
