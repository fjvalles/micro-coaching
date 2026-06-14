class ResourceDelivery < ApplicationRecord
  belongs_to :resource
  belongs_to :participant
  belongs_to :conversation, optional: true

  validates :moment, presence: true, allow_blank: true
end
