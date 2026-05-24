require "tempfile"

module Openai
  class AudioTranscriber
    include Openai::Retryable

    Result = Struct.new(:text, :language, :duration, :model, keyword_init: true)

    def initialize(bytes:, filename:, mime_type: nil, language: "es", api_key: ENV["OPENAI_API_KEY"], model: nil)
      @bytes     = bytes
      @filename  = filename
      @mime_type = mime_type
      @language  = language
      @api_key   = api_key
      @model     = model || Setting.fetch("openai_transcription_model").presence || "gpt-4o-mini-transcribe"
    end

    def call
      if Setting.fetch("openai_dry_run_global")
        return Result.new(text: "[dry-run transcription]", language: @language, duration: nil, model: "dry-run")
      end

      raise ArgumentError, "OPENAI_API_KEY missing" if @api_key.blank?

      ext = File.extname(@filename)
      Tempfile.open([ "wa_audio", ext ], binmode: true) do |tempfile|
        tempfile.write(@bytes)
        tempfile.flush
        tempfile.rewind

        params = { model: @model, file: tempfile, language: @language, response_format: "json" }
        response = with_retries { http_client.audio.transcribe(parameters: params) }
        text = response.is_a?(Hash) ? response["text"].to_s : response.to_s

        Result.new(
          text: text.strip,
          language: response.is_a?(Hash) ? response["language"] : @language,
          duration: response.is_a?(Hash) ? response["duration"] : nil,
          model: @model
        )
      end
    end

    private

    def http_client
      @http_client ||= ::OpenAI::Client.new(access_token: @api_key, request_timeout: 60)
    end
  end
end
