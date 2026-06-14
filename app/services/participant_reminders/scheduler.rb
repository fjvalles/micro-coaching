module ParticipantReminders
  class Scheduler
    Result = Struct.new(:scheduled, :reminder, :scheduled_at, :reason, :message, keyword_init: true) do
      def scheduled? = scheduled
    end

    def initialize(participant:, text:, source_conversation:, now: Time.current)
      @participant = participant
      @text = text.to_s
      @source_conversation = source_conversation
      @now = now
    end

    def call
      return rejected(:disabled) unless Setting.fetch("participant_reminders_enabled")

      parsed = Parser.new(text: @text, participant: @participant, now: @now).call
      return rejected(parsed.reason) unless parsed.reminder? && parsed.scheduled_at

      scheduled_at = parsed.scheduled_at
      validation_reason = validate_schedule(scheduled_at)
      return rejected(validation_reason, scheduled_at: scheduled_at) if validation_reason

      reminder, created = find_or_create_reminder!(scheduled_at, parsed.metadata)
      SendParticipantReminderJob.set(wait_until: reminder.scheduled_at).perform_later(reminder.id) if created

      Result.new(
        scheduled: true,
        reminder: reminder,
        scheduled_at: reminder.scheduled_at,
        reason: "scheduled",
        message: scheduled_message(reminder.scheduled_at)
      )
    end

    private

    def validate_schedule(scheduled_at)
      return :too_soon if scheduled_at < @now + Setting.fetch("participant_reminder_min_lead_minutes").to_i.minutes
      return :too_far if scheduled_at > @now + Setting.fetch("participant_reminder_max_horizon_days").to_i.days
      return :quiet_hours if quiet_hours?(scheduled_at)
      return :too_many_active if active_count >= Setting.fetch("participant_reminder_max_active").to_i
      return :too_many_for_day if reminders_for_day(scheduled_at) >= Setting.fetch("participant_reminder_max_per_day").to_i

      nil
    end

    def find_or_create_reminder!(scheduled_at, metadata)
      reminder = nil
      created = false

      ParticipantReminder.transaction(requires_new: true) do
        reminder = ParticipantReminder.find_or_initialize_by(source_conversation: @source_conversation)
        if reminder.new_record?
          created = true
          reminder.assign_attributes(
            participant: @participant,
            scheduled_at: scheduled_at,
            timezone: @participant.timezone,
            requested_text: @text,
            body: reminder_body,
            metadata: metadata
          )
          reminder.save!
        end
      end

      reminder.define_singleton_method(:previously_new_record?) { created }
      [ reminder, created ]
    rescue ActiveRecord::RecordNotUnique
      [ ParticipantReminder.find_by!(source_conversation: @source_conversation), false ]
    end

    def reminder_body
      Setting.fetch("participant_reminder_body_text").to_s
             .gsub("%{name}", @participant.name.to_s)
             .gsub("%{day}", @participant.current_day.to_s)
    end

    def scheduled_message(scheduled_at)
      when_text = I18n.l(scheduled_at.in_time_zone(@participant.timezone), format: :short)
      Setting.fetch("participant_reminder_scheduled_reply_text").to_s.gsub("%{when}", when_text)
    end

    def rejected(reason, scheduled_at: nil)
      Result.new(
        scheduled: false,
        scheduled_at: scheduled_at,
        reason: reason,
        message: rejection_message(reason)
      )
    end

    def rejection_message(reason)
      key = reason == :disabled ? "participant_reminder_disabled_reply_text" : "participant_reminder_rejected_reply_text"
      Setting.fetch(key).to_s
    end

    def active_count
      ParticipantReminder.active_for(@participant).count
    end

    def reminders_for_day(scheduled_at)
      ParticipantReminder.for_local_day(@participant, scheduled_at.in_time_zone(@participant.timezone).to_date)
                         .where(status: %w[pending sent])
                         .count
    end

    def quiet_hours?(scheduled_at)
      local_hour = scheduled_at.in_time_zone(@participant.timezone).hour
      starts_at = Setting.fetch("participant_reminder_quiet_hours_start").to_i
      ends_at = Setting.fetch("participant_reminder_quiet_hours_end").to_i
      return false if starts_at == ends_at

      starts_at < ends_at ? (starts_at...ends_at).cover?(local_hour) : (local_hour >= starts_at || local_hour < ends_at)
    end
  end
end
