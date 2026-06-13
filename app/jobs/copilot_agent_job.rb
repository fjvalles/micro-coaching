class CopilotAgentJob < ApplicationJob
  queue_as :default

  # Runs the copilot's function-calling loop for a session after a user turn.
  # Gated by copilot_enabled. Errors surface as an assistant message (and Sentry)
  # rather than a silent dead chat.
  def perform(session_id)
    return unless Setting.fetch("copilot_enabled")

    session = CopilotSession.find_by(id: session_id)
    return unless session

    Copilot::AgentRunner.new(session: session).call
  rescue StandardError => e
    Sentry.capture_exception(e) if defined?(Sentry)
    session&.copilot_messages&.create!(
      role: :assistant,
      content: "[error] No se pudo completar la respuesta: #{e.message}"
    )
  end
end
