class ParticipantReminder < ApplicationRecord
  STATUSES = %w[pending sent failed canceled].freeze

  belongs_to :participant
  belongs_to :source_conversation, class_name: "Conversation", optional: true
  belongs_to :sent_conversation, class_name: "Conversation", optional: true

  enum :status, STATUSES.index_with(&:itself)

  validates :status, :scheduled_at, :timezone, :requested_text, :body, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :body, length: { maximum: 500 }
  validates :requested_text, length: { maximum: 2_000 }

  scope :due, ->(now = Time.current) { pending.where(scheduled_at: ..now) }
  scope :active_for, ->(participant) { pending.where(participant: participant) }
  scope :for_local_day, lambda { |participant, local_day|
    zone = ActiveSupport::TimeZone[participant.timezone] || Time.zone
    from = zone.local(local_day.year, local_day.month, local_day.day).utc
    where(participant: participant, scheduled_at: from...(from + 1.day))
  }

  def local_scheduled_at
    scheduled_at.in_time_zone(timezone)
  end
end
