class CheckinEveningJob < ApplicationJob
  queue_as :default

  def perform
    program_totals = Program.pluck(:id, :total_days).to_h
    default_checkin_hour = Setting.fetch("checkin_hour").to_i

    Participant.kept.active.find_each do |participant|
      checkin_hour = participant.checkin_hour || default_checkin_hour
      next unless participant.local_time.hour == checkin_hour

      total = program_totals[participant.program_id] || 14
      next if participant.current_day < 1 || participant.current_day > total

      CheckinForParticipantJob.perform_later(participant.id)
    end
  end
end
