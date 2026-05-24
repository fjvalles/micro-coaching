class MorningWakeForParticipantJob < ApplicationJob
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    day_content = participant.day_content
    return unless day_content

    today_local = participant.local_time.to_date
    already_sent = participant.conversations.kept
                     .where(moment: :morning_wake, day_number: participant.current_day)
                     .where("created_at >= ?", today_local.in_time_zone(participant.timezone).beginning_of_day)
                     .exists?
    return if already_sent

    result = Openai::MorningMessageGenerator.new(
      participant: participant, day_content: day_content
    ).call

    Whatsapp::TemplateSender.new(
      participant: participant,
      template_name: day_content.template_name_whatsapp.presence || "despertar_dia_%02d" % day_content.day_number,
      moment: :morning_wake,
      day_number: day_content.day_number,
      variables: [ participant.name, result.body ]
    ).call

    delay = Setting.fetch("iareto_delay_minutes").to_i.minutes
    SendIaretoJob.set(wait: delay).perform_later(participant.id)
  end
end
