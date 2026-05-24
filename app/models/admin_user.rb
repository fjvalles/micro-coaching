class AdminUser < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :lockable, :validatable

  validates :name, presence: true
end
