class DayContent < ApplicationRecord
  has_paper_trail meta: { source: proc { PaperTrail.request.controller_info.to_h[:source] } }
  belongs_to :program

  enum :phase, { see: 0, choose: 1, anchor: 2 }

  validates :day_number, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :day_number, uniqueness: { scope: :program_id }
  validates :title, presence: true
  validates :phase, presence: true

  after_save :sync_prompt_template

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

  def prompt_template
    PromptTemplate.find_by(key: "day_system_prompt", program_id: program_id, day_number: day_number)
  end

  private

  def sync_prompt_template
    return unless saved_change_to_attribute?(:ai_system_prompt)
    body = ai_system_prompt.to_s
    return if body.blank?

    template = PromptTemplate.find_or_create_by!(
      key: "day_system_prompt", program_id: program_id, day_number: day_number
    ) do |t|
      t.name = "System prompt día #{day_number}"
      t.description = "Instrucciones específicas usadas por el generador del día."
      t.current_body = body
      t.current_version = 0
      t.source = "day_content"
    end
    template.record_version!(body: body, origin: "day_content", change_note: "Editado desde DayContent")
  rescue => e
    Rails.logger.warn("DayContent#sync_prompt_template failed: #{e.message}")
  end
end
