class PendingResponse < ApplicationRecord
  include Discard::Model

  STATUSES = %w[pending approved sent rejected].freeze
  MODES    = %w[manual suggest approve auto].freeze
  KINDS    = %w[text template].freeze

  belongs_to :participant
  belongs_to :conversation, optional: true
  belongs_to :approved_by, class_name: "AdminUser", optional: true

  validates :status,        inclusion: { in: STATUSES }
  validates :mode,          inclusion: { in: MODES }
  validates :delivery_kind, inclusion: { in: KINDS }
  validates :moment,        presence: true
  validates :draft_body,    presence: true, unless: -> { mode == "manual" }

  scope :kept,      -> { undiscarded }
  scope :pending_action, -> { kept.where(status: %w[pending approved]) }
  scope :awaiting,  -> { kept.where(status: "pending") }
  scope :recent_first, -> { order(created_at: :desc) }

  def pending?  = status == "pending"
  def approved? = status == "approved"
  def sent?     = status == "sent"
  def rejected? = status == "rejected"

  def actionable?
    pending? || approved?
  end
end
