class ProgramAssistantAgentJob < ApplicationJob
  queue_as :default

  # Runs the program assistant's function-calling loop for a session after a
  # user turn. Gated by program_assistant_enabled. Errors surface as an
  # assistant message (and Sentry) rather than a silent dead chat.
  def perform(session_id)
    return unless Setting.fetch("program_assistant_enabled")

    session = ProgramAssistantSession.find_by(id: session_id)
    return unless session

    ProgramAssistant::AgentRunner.new(session: session).call
  rescue StandardError => e
    Sentry.capture_exception(e) if defined?(Sentry)
    session&.program_assistant_messages&.create!(
      role: :assistant,
      content: "[error] No se pudo completar la respuesta: #{e.message}"
    )
  end
end
