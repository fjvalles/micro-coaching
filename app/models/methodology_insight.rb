class MethodologyInsight < ApplicationRecord
  SCOPES = %w[
    key_pattern_cluster
    voice_trend_by_phase
    prompt_finding_digest
    phase_kpi
    stuck_pattern
    prompt_evolution
  ].freeze

  belongs_to :program, optional: true

  validates :scope, presence: true, inclusion: { in: SCOPES }
  validates :generated_at, presence: true

  scope :recent, -> { order(generated_at: :desc) }
  scope :for_scope, ->(s) { where(scope: s) }
  scope :for_program, ->(program_id) { program_id ? where(program_id: program_id) : all }

  def self.latest_for(scope, program: nil)
    program_id = program.respond_to?(:id) ? program.id : program
    for_scope(scope).for_program(program_id).recent.first
  end
end
