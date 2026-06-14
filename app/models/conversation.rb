class Conversation < ApplicationRecord
  include Discard::Model

  belongs_to :participant
  has_many :pending_responses, dependent: :destroy
  has_many :skill_detections, dependent: :destroy
  has_many :resource_deliveries, dependent: :nullify

  enum :moment, {
    welcome: 0,
    morning_wake: 1,
    iareto: 2,
    checkin_question: 3,
    checkin_response: 4,
    free_user: 5,
    free_assistant: 6,
    manifesto: 7,
    admin_manual: 8,
    program_intake: 9,
    program_overview: 10,
    nivel2_offer: 11
  }

  enum :role, { user: 0, assistant: 1, system: 2 }

  validates :moment, presence: true
  validates :role, presence: true

  scope :kept, -> { undiscarded }
  scope :chronological, -> { order(:created_at) }
  scope :failed, -> { where.not(error_message: nil) }
  scope :for_day, ->(day) { where(day_number: day) }

  after_commit :broadcast_conversations

  private

  def broadcast_conversations
    broadcast_replace_later_to(
      "participant_#{participant_id}_conversations",
      target: "participant_conversations",
      partial: "admin/participants/conversations",
      locals: { participant: participant }
    )
  end
end
