class MorningWakeForParticipantJob < ApplicationJob
  include IdempotentOutbound
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    day_content = participant.day_content
    return unless day_content

    return if already_handled?(participant: participant, moment: :morning_wake, day_number: participant.current_day)

    mode = ResponseMode.for(participant)
    ai_body, ai_meta = generate_ai_body(participant, day_content, mode)

    template_name = Whatsapp::DailyTemplateName.call(
      prefix: "despertar",
      day_number: day_content.day_number,
      configured_name: day_content.template_name_whatsapp
    )
    dispatch_result = Outbound::Dispatcher.new(
      participant: participant, moment: :morning_wake, day_number: day_content.day_number, mode: mode
    ).send_template(
      template_name: template_name,
      variables: [ participant.name, ai_body ],
      body_preview: ai_body,
      ai: ai_meta
    )

    return unless dispatch_result.delivered?

    delay = Setting.fetch("iareto_delay_minutes").to_i.minutes
    SendIaretoJob.set(wait: delay).perform_later(participant.id)
  end

  private

  def generate_ai_body(participant, day_content, mode)
    return [ "", {} ] if mode == "manual"

    result = Openai::MorningMessageGenerator.new(participant: participant, day_content: day_content).call
    ai_meta = {
      prompt_used: result.prompt_used,
      tokens_input: result.tokens_input,
      tokens_output: result.tokens_output,
      model: result.model
    }
    [ result.body, ai_meta ]
  end
end
