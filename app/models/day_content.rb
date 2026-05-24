class DayContent < ApplicationRecord
  belongs_to :program

  enum :phase, { see: 0, choose: 1, anchor: 2 }

  validates :day_number, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :day_number, uniqueness: { scope: :program_id }
  validates :title, presence: true
  validates :phase, presence: true

  scope :ordered, -> { order(:day_number) }
  scope :active, -> { where(active: true) }
  scope :for_programs, ->(program_ids) { where(program_id: program_ids) if program_ids.present? }
  scope :for_day_numbers, ->(day_numbers) { where(day_number: day_numbers) if day_numbers.present? }
  scope :for_phases, ->(phases) { where(phase: phases) if phases.present? }
  scope :for_statuses, lambda { |statuses|
    normalized_statuses = Array(statuses).reject(&:blank?)
    next all if normalized_statuses.empty?

    conditions = []
    conditions << arel_table[:active].eq(true) if normalized_statuses.include?("active")
    conditions << arel_table[:active].eq(false) if normalized_statuses.include?("inactive")

    where(conditions.reduce { |combined, condition| combined.or(condition) })
  }
  scope :search_text, lambda { |query|
    if query.present?
      sanitized_query = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"

      where(
        "title ILIKE :q OR template_name_whatsapp ILIKE :q OR morning_template ILIKE :q OR iareto_text ILIKE :q OR checkin_questions ILIKE :q OR ai_system_prompt ILIKE :q",
        q: sanitized_query
      )
    end
  }
end
