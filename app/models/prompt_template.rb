class PromptTemplate < ApplicationRecord
  include Discard::Model

  belongs_to :program, optional: true
  has_many :prompt_versions, -> { order(version: :desc) }, dependent: :destroy
  has_many :prompt_executions, dependent: :nullify
  has_many :prompt_analyses, dependent: :destroy

  validates :key, presence: true
  validates :name, presence: true
  validates :key, uniqueness: { scope: [ :program_id, :day_number ] }

  scope :kept, -> { undiscarded }
  scope :ordered, -> { order(:key, :day_number) }

  def latest_version
    prompt_versions.first
  end

  def label
    if day_number.present?
      "#{name} (día #{day_number})"
    else
      name
    end
  end

  def record_version!(body:, author: nil, change_note: nil, origin: "admin")
    return latest_version if latest_version && latest_version.body == body.to_s

    next_version = (current_version || 0) + 1
    pv = prompt_versions.create!(
      version: next_version,
      body: body.to_s,
      change_note: change_note,
      author_id: author&.id,
      origin: origin
    )
    update!(current_body: body.to_s, current_version: next_version)
    pv
  end
end
