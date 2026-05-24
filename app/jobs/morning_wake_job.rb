class MorningWakeJob < ApplicationJob
  queue_as :default

  def perform
    wake_hour = Setting.fetch("wake_hour").to_i
    Participant.kept.active.find_each do |participant|
      next unless participant.local_time.hour == wake_hour
      next if participant.current_day < 1 || participant.current_day > 14
      MorningWakeForParticipantJob.perform_later(participant.id)
    end
  end
end
