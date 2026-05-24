module Openai
  module Retryable
    RETRYABLE_ERRORS = [
      Faraday::TooManyRequestsError,
      Faraday::ServerError,
      Faraday::TimeoutError
    ].freeze

    private

    def with_retries(max: nil)
      max ||= Setting.fetch("openai_retry_max") || 3
      attempt = 0
      begin
        attempt += 1
        yield
      rescue *RETRYABLE_ERRORS => e
        raise e if attempt >= max
        sleep(0.5 * (2**attempt))
        retry
      end
    end
  end
end
