class RefreshMethodologyInsightsJob < ApplicationJob
  queue_as :default

  def perform(program_id: nil)
    if program_id
      program = Program.find_by(id: program_id)
      Methodology::InsightBuilder.call(program: program) if program
    else
      Program.where(active: true).find_each do |program|
        Methodology::InsightBuilder.call(program: program)
      end
      # Also a global snapshot (program: nil)
      Methodology::InsightBuilder.call(program: nil)
    end
  end
end
