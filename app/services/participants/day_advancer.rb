module Participants
  class DayAdvancer
    def initialize(participant:)
      @participant = participant
    end

    def call
      return :skipped unless @participant.active?

      today_local = @participant.local_time.to_date
      yesterday_local = today_local - 1.day
      last_checkin = @participant.conversations.kept
                       .where(moment: :checkin_response, day_number: @participant.current_day)
                       .order(created_at: :desc).first

      unless last_checkin && [today_local, yesterday_local].include?(last_checkin.created_at.in_time_zone(@participant.timezone).to_date)
        Rails.logger.info("DayAdvancer: no check-in today for participant=#{@participant.id}")
        return :no_checkin
      end

      total = @participant.program&.total_days || 14
      if @participant.current_day >= total
        complete!(total)
        :completed
      else
        with_ai_trail { @participant.update!(current_day: @participant.current_day + 1) }
        :advanced
      end
    end

    private

    def complete!(total)
      with_ai_trail { @participant.update!(status: :completed, completed_at: Time.current, current_day: total + 1) }
      @participant.current_enrollment&.update!(status: :completed, completed_at: Time.current)
      GenerateAndSendManifestoJob.perform_later(@participant.id)
      # Day-14 upsell: invite the participant to design a paid personalized Nivel 2.
      # Self-gates on nivel2_offer_enabled + idempotency inside the job.
      SendNivel2OfferJob.perform_later(@participant.id)
    end

    def with_ai_trail(&block)
      PaperTrail.request(whodunnit: "ai:DayAdvancer", controller_info: { source: "ai" }, &block)
    end
  end
end
