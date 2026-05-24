class PendingResponseMailerJob < ApplicationJob
  queue_as :default

  def perform(pending_response_id)
    PendingResponseMailer.new_pending(pending_response_id).deliver_now
  rescue StandardError => e
    Rails.logger.warn("PendingResponseMailerJob error: #{e.message}")
  end
end
