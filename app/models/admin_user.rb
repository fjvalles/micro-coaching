class AdminUser < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :lockable, :timeoutable, :validatable

  has_many :copilot_sessions, dependent: :destroy

  validates :name, presence: true
end
