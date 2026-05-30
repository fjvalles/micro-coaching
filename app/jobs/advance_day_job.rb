class AdvanceDayJob < ApplicationJob
  queue_as :default

  def perform
    # No eager-load of :program — DayAdvancer only touches it on the advance path
    # (after the no-checkin early return), so preloading it for the whole batch is wasted.
    Participant.kept.active.find_each do |participant|
      Participants::DayAdvancer.new(participant: participant).call
    end
  end
end
