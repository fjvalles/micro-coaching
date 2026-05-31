class Participant < ApplicationRecord
  include Discard::Model

  has_paper_trail meta: { source: proc { PaperTrail.request.controller_info.to_h[:source] } }

  belongs_to :program, optional: true
  belongs_to :company, optional: true

  enum :status, { pending: 0, active: 1, completed: 2, paused: 3, awaiting_payment: 4 }

  # Passwordless portal login. Token embeds email so changing it invalidates old links.
  generates_token_for :portal_login, expires_in: 30.minutes do
    email
  end

  has_many :conversations, dependent: :destroy
  has_many :daily_reports, dependent: :destroy
  has_many :pending_responses, dependent: :destroy

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

  # Per-company coach override; nil falls back to the global coach_name Setting
  # inside Openai::ProgramManifesto.
  def coach_name
    company&.coach_name.presence
  end

  # Individuals pay for themselves. Company members don't pay individually unless
  # their company opts out of covering membership.
  def pays_individually?
    company_id.blank? || company&.covers_membership == false
  end

  # True when this participant must pay before being activated: they pay for
  # themselves AND individual membership is actually being charged (price set +
  # Webpay enabled). Drives payment-gated enrollment and the portal pay CTA.
  def payment_required?
    pays_individually? &&
      Setting.fetch("membership_price_clp").to_i.positive? &&
      Setting.fetch("webpay_enabled")
  end

  def latest_report
    @latest_report ||= daily_reports.order(reported_at: :desc).first
  end

  def local_time(now = Time.current)
    now.in_time_zone(timezone)
  end

  def in_24h_window?(now = Time.current)
    last_inbound = last_inbound_at
    return false unless last_inbound

    (now - last_inbound) < 24.hours
  end

  def last_inbound_at
    conversations.kept.where(role: "user").maximum(:created_at)
  end

  # Count of free-chat inbound messages (moment: free_user) received today in the
  # participant's local timezone. Drives the max_free_messages_per_day cap.
  # Check-in / welcome inbounds are reclassified off free_user, so they don't count.
  def free_inbounds_today(now = Time.current)
    conversations.kept
                 .where(role: "user", moment: "free_user")
                 .where("created_at >= ?", local_time(now).beginning_of_day)
                 .count
  end

  def day_content
    @day_content ||= program && DayContent.find_by(program: program, day_number: current_day)
  end

  def reset_memoization!
    @day_content = nil
    @latest_report = nil
  end
end
