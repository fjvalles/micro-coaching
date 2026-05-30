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
      participant = Participant.new(
        name: @name,
        phone_e164: @phone_e164,
        program: @program,
        timezone: @timezone,
        email: @email,
        role: @role,
        status: :active,
        current_day: 1,
        enrolled_at: Time.current,
        started_at: Time.current
      )
      # `company` is the Company association; public self-enroll only has a free-text
      # company name, so store it on the legacy string column for later admin mapping.
      participant.write_attribute(:company, @company) if @company.present?
      participant.save!
      SendWelcomeJob.perform_later(participant.id)
      participant
    end
  end
end
