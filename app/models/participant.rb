class Participant < ApplicationRecord
  include Discard::Model

  has_paper_trail meta: { source: proc { PaperTrail.request.controller_info.to_h[:source] } }

  belongs_to :program, optional: true
  belongs_to :company, optional: true

  enum :status, { pending: 0, active: 1, completed: 2, paused: 3, awaiting_payment: 4, intake: 5 }

  # Passwordless portal login. Token embeds email so changing it invalidates old links.
  generates_token_for :portal_login, expires_in: 30.minutes do
    email
  end

  has_many :conversations, dependent: :destroy
  has_many :daily_reports, dependent: :destroy
  has_many :pending_responses, dependent: :destroy
  has_many :skill_detections, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :resource_deliveries, dependent: :destroy
  has_many :participant_reminders, dependent: :destroy

  validates :name, presence: true
  validates :phone_e164, presence: true, uniqueness: true,
            format: { with: /\A\+\d{8,15}\z/, message: "must be E.164 format like +521234567890" }
  validates :timezone, presence: true
  validates :current_day, numericality: { greater_than_or_equal_to: 0 }
  validates :initial_pattern, length: { maximum: 500 }, allow_blank: true
  validates :focus_hint, length: { maximum: 1000 }, allow_blank: true
  validates :coach_notes, length: { maximum: 5000 }, allow_blank: true
  validates :wake_hour, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 23 }, allow_nil: true
  validates :checkin_hour, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 23 }, allow_nil: true
  validate :current_day_within_program_range

  scope :kept, -> { undiscarded }
  # Participants whose AI-generated program is built and waiting for human review
  # before activation (Programs::Approver). Drives the admin review queue.
  scope :awaiting_program_review, -> { where("intake_state->>'awaiting_review' = 'true'") }

  # The active ledger row for the program the participant is currently running.
  # Used to mark a cycle completed / advance to the next program.
  def current_enrollment
    enrollments.find_by(program_id: program_id, status: :active)
  end

  # Opens a new active ledger cycle for the given program. Idempotent: a program
  # that already has an active cycle is left untouched. cycle_number is global per
  # participant so re-running the same program later gets a fresh, unique cycle.
  def start_enrollment!(target_program = program)
    return if target_program.nil?
    return if enrollments.active.exists?(program_id: target_program.id)

    enrollments.create!(
      program: target_program,
      cycle_number: (enrollments.maximum(:cycle_number) || 0) + 1,
      status: :active,
      started_at: Time.current
    )
  end

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

  # Resources delivered to this participant (via WhatsApp), most recent first,
  # deduped per resource and filtered to still-kept records. Drives the portal
  # Recursos tab and the dashboard preview.
  def shared_resources(limit: nil)
    result = resource_deliveries.includes(:resource)
                                .order(created_at: :desc)
                                .select { |d| d.resource&.kept? }
                                .uniq(&:resource_id)
    limit ? result.first(limit) : result
  end

  # Human skills most frequently detected for this participant in a recent window,
  # ordered by detection frequency. Drives the admin skill profile.
  def dominant_skills(limit: 5, since: 30.days.ago)
    ordered_ids = skill_detections.since(since)
                                  .group(:skill_id)
                                  .order(Arel.sql("COUNT(*) DESC"))
                                  .limit(limit).pluck(:skill_id)
    by_id = Skill.where(id: ordered_ids).index_by(&:id)
    ordered_ids.filter_map { |id| by_id[id] }
  end

  # Intake state machine helpers. intake_state jsonb shape:
  #   { "step" => Integer (next unanswered question index), "answers" => { key => text },
  #     "generation_requested_at" => String, "awaiting_review" => Boolean }
  def intake_step
    intake_state.fetch("step", 0).to_i
  end

  def intake_answers
    intake_state.fetch("answers", {})
  end

  def intake_awaiting_review?
    intake_state["awaiting_review"] == true
  end

  def intake_generation_requested?
    intake_state["generation_requested_at"].present?
  end

  # The reviewed personalized-program TEMPLATE this participant generated (if any),
  # which they pay to unlock as their Nivel 2.
  def nivel2_template
    template_id = intake_state["template_program_id"]
    template_id && Program.templates.find_by(id: template_id)
  end

  # True when a paid Nivel 2 has been vetted by an admin and is awaiting the
  # participant's payment (drives the portal pay CTA).
  def nivel2_offered?
    intake_state["offered_at"].present? && nivel2_template&.paid?
  end

  # Conditional guarantee: a participant who completed a PAID program may claim one
  # free extra cycle if still inside the claim window and hasn't claimed before.
  def guarantee_eligible?
    days = Setting.fetch("guarantee_claim_window_days").to_i
    return false unless days.positive?
    return false unless completed? && guarantee_claimed_at.nil?
    return false unless program&.paid?

    completed_at.present? && completed_at > days.days.ago
  end

  def local_time(now = Time.current)
    now.in_time_zone(timezone)
  end

  # True while the day-14 founder offer window is open (founder price + expiring
  # bonus apply). Anchored on when SendNivel2OfferJob stamped nivel2_offer_sent_at.
  def nivel2_offer_active?(now = Time.current)
    return false if nivel2_offer_sent_at.blank?

    nivel2_offer_sent_at > Setting.fetch("nivel2_offer_window_hours").to_i.hours.before(now)
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

  private

  def current_day_within_program_range
    return if program.blank? || current_day.blank?
    return unless current_day.is_a?(Integer)

    max_day = completed? ? program.total_days + 1 : program.total_days
    return if current_day <= max_day

    errors.add(:current_day, "must be within the program range")
  end
end
