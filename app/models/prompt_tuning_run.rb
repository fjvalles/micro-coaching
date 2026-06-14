class PromptTuningRun < ApplicationRecord
  STATUSES = %w[observed proposed applied rejected rolled_back invalid no_change].freeze
  MODES = %w[observe propose apply].freeze
  CHANGE_KINDS = %w[append_bullet tighten_bullet no_change].freeze

  belongs_to :conversation_quality_score, optional: true
  belongs_to :prompt_version, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :mode, inclusion: { in: MODES }
  validates :change_kind, inclusion: { in: CHANGE_KINDS }, allow_blank: true
  validates :window_start, :window_end, presence: true
  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "proposed") }
  scope :applied, -> { where(status: "applied") }
  scope :for_window, ->(from, to) { where(window_start: from, window_end: to) }

  def proposed? = status == "proposed"
  def applied? = status == "applied"
  def rolled_back? = status == "rolled_back"
  def rejected? = status == "rejected"

  def apply!(author: nil, guardrails: proposed_guardrails)
    validator = Guardrails::Validator.new(
      current_guardrails: current_guardrails,
      proposed_guardrails: guardrails
    ).call

    unless validator.valid?
      update!(status: "invalid", validation_errors: validator.errors)
      return false
    end

    template = self.class.free_response_template
    version = template.record_version!(
      body: guardrails,
      author: author,
      origin: "auto_tuner",
      change_note: "Auto-tuning de estilo conversacional desde run #{id}"
    )

    Setting.set("free_chat_style_guardrails", guardrails)
    update!(
      status: "applied",
      previous_guardrails: current_guardrails,
      applied_guardrails: guardrails,
      prompt_version: version,
      baseline_score: score,
      applied_at: Time.current,
      validation_errors: []
    )
    self.class.capture_observability("Prompt tuning applied", run_id: id, score: score)
    true
  end

  def reject!
    update!(status: "rejected", rejected_at: Time.current)
  end

  def rollback!(post_score:)
    return false if previous_guardrails.blank?

    Setting.set("free_chat_style_guardrails", previous_guardrails)
    version = self.class.free_response_template.record_version!(
      body: previous_guardrails,
      origin: "auto_tuner",
      change_note: "Rollback automático de prompt tuning run #{id}"
    )
    update!(
      status: "rolled_back",
      post_score: post_score,
      prompt_version: version,
      rolled_back_at: Time.current
    )
    self.class.capture_observability("Prompt tuning rolled back", run_id: id, score: post_score)
    true
  end

  def self.free_response_template
    PromptTemplate.find_or_create_by!(key: "free_response_style_guardrails", program_id: nil, day_number: nil) do |template|
      template.name = "Guardrails de estilo de respuesta libre"
      template.description = "Guardrails editables de estilo para chat libre."
      template.source = "service"
      template.current_body = Setting.fetch("free_chat_style_guardrails").to_s
    end
  end

  def self.capture_observability(message, extra = {})
    Rails.logger.info("[PromptTuning] #{message} #{extra.inspect}")
    return unless defined?(Sentry) && Sentry.respond_to?(:capture_message)

    Sentry.capture_message("[PromptTuning] #{message}", level: :info, extra: extra)
  end
end
