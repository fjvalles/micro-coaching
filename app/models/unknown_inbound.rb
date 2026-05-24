class UnknownInbound < ApplicationRecord
  validates :phone, presence: true
  validates :wamid, uniqueness: true, allow_nil: true
end
