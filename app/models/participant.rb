class Participant < ApplicationRecord
  include Discard::Model

  has_paper_trail meta: { source: proc { PaperTrail.request.controller_info.to_h[:source] } }

  belongs_to :program, optional: true

  enum :status, { pending: 0, active: 1, completed: 2, paused: 3 }

  has_many :conversations, dependent: :destroy
  has_many :daily_reports, dependent: :destroy

  validates :name, presence: true
  validates :phone_e164, presence: true, uniqueness: true,
            format: { with: /\A\+\d{8,15}\z/, message: "must be E.164 format like +521234567890" }
  validates :timezone, presence: true
  validates :current_day, numericality: { greater_than_or_equal_to: 0 }
  validates :initial_pattern, length: { maximum: 500 }, allow_blank: true

  scope :kept, -> { undiscarded }

  def phase
    day_content&.phase&.to_sym || :pending
  end

  def latest_report
    @latest_report ||= daily_reports.order(reported_at: :desc).first
  end

  def local_time(now = Time.current)
    now.in_time_zone(timezone)
  end

  def in_24h_window?(now = Time.current)
    last_inbound = conversations.kept
                                .where(role: "user")
                                .order(created_at: :desc)
                                .pick(:created_at)
    return false unless last_inbound

    (now - last_inbound) < 24.hours
  end

  def day_content
    @day_content ||= program && DayContent.find_by(program: program, day_number: current_day)
  end

  def reset_memoization!
    @day_content = nil
    @latest_report = nil
  end
end
