class Resource < ApplicationRecord
  include Discard::Model

  RECENT_VERIFICATION_FALLBACK_DAYS = 30

  belongs_to :program, optional: true
  has_many :resource_deliveries, dependent: :destroy

  enum :kind, {
    video: "video",
    article: "article",
    audio_ref: "audio_ref"
  }

  enum :status, {
    pending: "pending",
    verified: "verified",
    approved: "approved",
    rejected: "rejected",
    dead: "dead"
  }

  enum :source, {
    manual: "manual",
    admin_search: "admin_search",
    program_seed: "program_seed",
    gap_detection: "gap_detection"
  }

  validates :title, :url, :kind, :status, :source, presence: true
  validates :url, uniqueness: { case_sensitive: false }
  validate :topics_are_strings

  before_validation :normalize_url
  before_validation :normalize_topics

  scope :kept, -> { undiscarded }
  scope :ordered, -> { order(updated_at: :desc) }
  scope :for_program, ->(program) {
    program_id = program.respond_to?(:id) ? program.id : program
    program_id.present? ? where(program_id: [ nil, program_id ]) : where(program_id: nil)
  }
  scope :sendable, -> {
    kept.approved.where("last_verified_at >= ?", recent_verification_cutoff)
  }
  scope :stale, -> {
    kept.where("last_verified_at IS NULL OR last_verified_at < ?", recent_verification_cutoff)
  }

  def self.recent_verification_cutoff
    days = Setting.fetch("resource_revalidation_days").presence || RECENT_VERIFICATION_FALLBACK_DAYS
    days.to_i.days.ago
  end

  def sendable?
    kept? && approved? && last_verified_at.present? && last_verified_at >= self.class.recent_verification_cutoff
  end

  private

  def normalize_url
    self.url = url.to_s.strip
  end

  def normalize_topics
    self.topics = Array(topics).map { |topic| topic.to_s.strip }.reject(&:blank?).uniq
  end

  def topics_are_strings
    errors.add(:topics, "debe ser una lista") unless topics.is_a?(Array)
  end
end
