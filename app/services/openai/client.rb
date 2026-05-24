module Openai
  class Client
    include Openai::Retryable

    Result = Struct.new(:content, :tokens_input, :tokens_output, :model, :latency_ms, keyword_init: true)

    DEFAULT_MODEL = "gpt-4.1-mini".freeze

    def initialize(api_key: ENV["OPENAI_API_KEY"], model: nil)
      @api_key = api_key
      @model   = model || Setting.fetch("openai_model").presence || DEFAULT_MODEL
    end

    def chat(messages:, max_tokens: nil, temperature: nil, response_format: nil)
      max_tokens  ||= Setting.fetch("openai_max_tokens_free")
      temperature ||= Setting.fetch("openai_temperature_generative")

      if Setting.fetch("openai_dry_run_global")
        return Result.new(
          content: "[dry-run] OpenAI desactivado vía openai_dry_run_global.",
          tokens_input: 0, tokens_output: 0, model: "dry-run", latency_ms: 0
        )
      end

      raise ArgumentError, "OPENAI_API_KEY missing" if @api_key.blank?

      params = {
        model: @model,
        messages: messages,
        max_tokens: max_tokens,
        temperature: temperature
      }
      params[:response_format] = response_format if response_format

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = with_retries { http_client.chat(parameters: params) }
      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      content = response.dig("choices", 0, "message", "content").to_s.strip
      usage = response["usage"] || {}

      Result.new(
        content: content,
        tokens_input: usage["prompt_tokens"].to_i,
        tokens_output: usage["completion_tokens"].to_i,
        model: response["model"] || @model,
        latency_ms: latency_ms
      )
    end

    private

    def http_client
      @http_client ||= ::OpenAI::Client.new(access_token: @api_key, request_timeout: 30)
    end
  end
end
