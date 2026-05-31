class SubscriptionBillingJob < ApplicationJob
  queue_as :default

  # Charges every active subscription whose next_billing_at is due. Idempotent: a
  # successful charge advances next_billing_at out of the billable scope, and a
  # failure reschedules to tomorrow, so re-running the same day won't double-charge.
  def perform
    return unless Setting.fetch("webpay_oneclick_enabled")

    Subscription.billable.find_each { |subscription| bill(subscription) }
  end

  private

  def bill(subscription)
    buy_order = Payment.next_buy_order
    result = Webpay::OneclickClient.new.charge(
      username:  subscription.tbk_username,
      tbk_user:  subscription.tbk_user,
      buy_order: buy_order,
      amount:    subscription.amount_clp
    )

    if result.success? && result.authorized
      subscription.record_charge!(buy_order: buy_order, result: result)
      subscription.schedule_next_cycle!
    else
      handle_failure(subscription)
    end
  end

  # Dunning: retry tomorrow until subscription_max_retries, then flag past_due.
  def handle_failure(subscription)
    attempts = subscription.failed_attempts + 1
    if attempts > Setting.fetch("subscription_max_retries").to_i
      subscription.update!(failed_attempts: attempts, status: :past_due)
      Rails.logger.warn("[Subscription past_due] id=#{subscription.id} participant=#{subscription.participant_id}")
      if defined?(Sentry) && Sentry.respond_to?(:capture_message)
        Sentry.capture_message("Subscription past_due: #{subscription.id}", level: :warning)
      end
    else
      subscription.update!(failed_attempts: attempts, next_billing_at: 1.day.from_now)
    end
  end
end
