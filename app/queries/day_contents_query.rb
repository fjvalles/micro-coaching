class DayContentsQuery
  FILTER_KEYS = %i[program_ids day_numbers phases statuses].freeze

  attr_reader :filters

  def self.from_params(params, program_context: nil)
    raw = params.permit(
      :program_id, :day_number, :phase, :status, :q,
      program_ids: [], day_numbers: [], phases: [], statuses: []
    )

    filters = {
      q: raw[:q].to_s.strip.presence,
      program_ids: normalize(raw[:program_ids], raw[:program_id]),
      day_numbers: normalize(raw[:day_numbers], raw[:day_number]),
      phases: normalize(raw[:phases], raw[:phase]),
      statuses: normalize(raw[:statuses], raw[:status])
    }

    new(filters, program_context: program_context)
  end

  def self.normalize(values, fallback)
    Array(values).reject(&:blank?).presence || Array(fallback).reject(&:blank?).presence || []
  end

  def initialize(filters, program_context: nil, base_scope: DayContent.all)
    @filters = filters
    @program_context = program_context
    @base_scope = base_scope
  end

  def resolve
    scope = @base_scope.includes(:program).left_joins(:program)
    scope = scope.for_programs(effective_program_ids)
    scope = scope.for_day_numbers(@filters[:day_numbers])
    scope = scope.for_phases(@filters[:phases])
    scope = scope.for_statuses(@filters[:statuses])
    scope = scope.search_text(@filters[:q])
    scope.order(Arel.sql("programs.name ASC"), :day_number, :title)
  end

  def to_h
    @filters
  end

  private

  def effective_program_ids
    @program_context ? [ @program_context.id ] : @filters[:program_ids]
  end
end
