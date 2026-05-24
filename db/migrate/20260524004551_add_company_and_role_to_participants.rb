class AddCompanyAndRoleToParticipants < ActiveRecord::Migration[7.2]
  def change
    add_column :participants, :company, :string
    add_column :participants, :role, :string
  end
end
