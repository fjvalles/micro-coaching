module Participants
  class Enroller
    def initialize(name:, phone_e164:, program: nil, timezone: ENV.fetch("DEFAULT_TIMEZONE", "America/Santiago"), email: nil, company: nil, role: nil)
      @name = name
      @phone_e164 = phone_e164
      @program = program || Program.default
      @timezone = timezone
      @email = email
      @company = company
      @role = role
    end

    def call
      participant = Participant.create!(
        name: @name,
        phone_e164: @phone_e164,
        program: @program,
        timezone: @timezone,
        email: @email,
        company: @company,
        role: @role,
        status: :active,
        current_day: 1,
        enrolled_at: Time.current,
        started_at: Time.current
      )
      SendWelcomeJob.perform_later(participant.id)
      participant
    end
  end
end
