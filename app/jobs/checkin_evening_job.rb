class CheckinEveningJob < ApplicationJob
  queue_as :default

  def perform
    checkin_hour = Setting.fetch("checkin_hour").to_i
    Participant.kept.active.find_each do |participant|
      next unless participant.local_time.hour == checkin_hour
      next if participant.current_day < 1 || participant.current_day > 14
      CheckinForParticipantJob.perform_later(participant.id)
    end
  end
end
