class AdvanceDayJob < ApplicationJob
  queue_as :default

  def perform
    Participant.kept.active.find_each do |participant|
      Participants::DayAdvancer.new(participant: participant).call
    end
  end
end
