module ResponseMode
  MODES = %w[manual suggest approve auto].freeze
  DEFAULT = "auto".freeze

  module_function

  # Precedence: participant > program > global Setting.
  def for(participant)
    return DEFAULT unless participant

    pick(participant.response_mode) ||
      pick(participant.program&.response_mode) ||
      pick(Setting.fetch("response_mode")) ||
      DEFAULT
  end

  def pick(value)
    v = value.to_s
    MODES.include?(v) ? v : nil
  end

  def auto?(participant)    = self.for(participant) == "auto"
  def manual?(participant)  = self.for(participant) == "manual"
  def suggest?(participant) = self.for(participant) == "suggest"
  def approve?(participant) = self.for(participant) == "approve"

  def queues_pending?(participant)
    %w[suggest approve manual].include?(self.for(participant))
  end
end
