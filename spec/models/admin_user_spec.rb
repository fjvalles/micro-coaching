require 'rails_helper'

RSpec.describe AdminUser, type: :model do
  describe 'validations' do
    it 'is valid with a name, email, and password' do
      admin = AdminUser.new(
        name: 'Admin User',
        email: 'admin@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
      expect(admin).to be_valid
    end

    it 'is invalid without a name' do
      admin = AdminUser.new(
        email: 'admin@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
      expect(admin).not_to be_valid
      expect(admin.errors[:name]).to include("can't be blank")
    end
  end
end
