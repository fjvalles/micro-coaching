class AdminUser < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :lockable, :timeoutable, :validatable

  validates :name, presence: true
end
