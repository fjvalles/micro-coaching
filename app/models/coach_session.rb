class CoachSession < ApplicationRecord
  include Discard::Model

  has_paper_trail meta: { source: proc { PaperTrail.request.controller_info.to_h[:source] } }

  belongs_to :participant
  belongs_to :coach, class_name: "AdminUser", foreign_key: "admin_user_id", optional: true

  # requested  → participant/admin proposed it, not yet confirmed
  # confirmed  → scheduled and agreed (eligible for reminders)
  # done       → already happened
  # cancelled  → called off
  enum :status, { requested: 0, confirmed: 1, done: 2, cancelled: 3 }

  validates :scheduled_at, presence: true
  validates :duration_minutes, numericality: { greater_than: 0 }
  validates :meeting_url, format: { with: %r{\Ahttps?://}, message: "debe ser una URL http(s)" },
                          allow_blank: true

  scope :kept,        -> { undiscarded }
  scope :upcoming,    -> { kept.where("scheduled_at >= ?", Time.current).order(:scheduled_at) }
  scope :past,        -> { kept.where(scheduled_at: ...Time.current).order(scheduled_at: :desc) }
  scope :chronological, -> { order(:scheduled_at) }

  # Confirmed sessions starting within `lead` from now that haven't been reminded
  # yet. Drives CoachSessionReminderJob. Idempotent via reminder_sent_at.
  scope :due_for_reminder, lambda { |lead, now = Time.current|
    kept.confirmed.where(reminder_sent_at: nil).where(scheduled_at: now..(now + lead))
  }

  def next_for_participant?
    confirmed? && scheduled_at.present? && scheduled_at >= Time.current
  end
end
