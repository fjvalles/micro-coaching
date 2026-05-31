module Participants
  # Creates a participant from a sign-up. Two outcomes:
  #   • payment NOT required (company-covered member, or Webpay off / price 0) →
  #     activated immediately via Participants::Activator (welcome sent).
  #   • payment required (individual + price set + Webpay on) → left in
  #     :awaiting_payment with no welcome; the Webpay commit activates them.
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
        status: :pending,
        current_day: 0,
        enrolled_at: Time.current
      )
      # `company` is the Company association; public self-enroll only has a free-text
      # company name, so store it on the legacy string column for later admin mapping.
      participant.write_attribute(:company, @company) if @company.present?

      if participant.payment_required?
        participant.status = :awaiting_payment
        participant.save!
        participant
      else
        participant.save!
        Participants::Activator.new(participant).call
      end
    end
  end
end
