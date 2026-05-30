class MorningWakeJob < ApplicationJob
  queue_as :default

  def perform
    wake_hour = Setting.fetch("wake_hour").to_i
    program_totals = Program.pluck(:id, :total_days).to_h

    Participant.kept.active.find_each do |participant|
      next unless participant.local_time.hour == wake_hour

      total = program_totals[participant.program_id] || 14
      next if participant.current_day < 1 || participant.current_day > total

      MorningWakeForParticipantJob.perform_later(participant.id)
    end
  end
end
