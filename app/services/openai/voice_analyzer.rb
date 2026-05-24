require "base64"
require "open3"
require "tempfile"

module Openai
  class VoiceAnalyzer
    include Openai::Retryable

    Result = Struct.new(
      :analysis, :prompt_used, :tokens_input, :tokens_output, :model, :skipped_reason,
      keyword_init: true
    )

    ANALYSIS_INSTRUCTION = <<~PROMPT.freeze
      Eres un analista paralingüístico. Recibes un audio en español de un participante
      en un programa de coaching y devuelves SOLO un objeto JSON con esta forma exacta:

      {
        "tone": "ej. cálido, tenso, contenido",
        "primary_emotion": "ej. tristeza, frustración, alivio, calma",
        "secondary_emotions": ["lista breve"],
        "energy_level": "bajo | medio | alto",
        "pace": "lento | medio | rápido",
        "volume": "suave | medio | fuerte",
        "vocal_qualities": ["ej. voz temblorosa", "pausas largas", "respiración entrecortada"],
        "sentiment": "negativo | neutro | positivo",
        "confidence": 0.0,
        "key_observations": "una o dos frases sobre lo que el audio sugiere más allá del texto"
      }

      No inventes contenido textual: limítate a lo que se puede inferir de la voz.
      Responde EXCLUSIVAMENTE el JSON, sin markdown.
    PROMPT

    def initialize(bytes:, mime_type:, api_key: ENV["OPENAI_API_KEY"], model: nil)
      @bytes     = bytes
      @mime_type = mime_type
      @api_key   = api_key
      @model     = model || Setting.fetch("openai_voice_analysis_model").presence || "gpt-4o-mini-audio-preview"
    end

    def call
      return skipped("voice_analysis_disabled") unless Setting.fetch("openai_voice_analysis_enabled")

      if Setting.fetch("openai_dry_run_global")
        return Result.new(
          analysis: { "tone" => "[dry-run]" }, prompt_used: ANALYSIS_INSTRUCTION,
          tokens_input: 0, tokens_output: 0, model: "dry-run"
        )
      end

      raise ArgumentError, "OPENAI_API_KEY missing" if @api_key.blank?

      converted = ensure_supported_format(@bytes, @mime_type)
      return skipped("ffmpeg_unavailable") unless converted

      audio_bytes, format = converted

      messages = [
        { role: "system", content: ANALYSIS_INSTRUCTION },
        { role: "user", content: [
          { type: "text", text: "Analiza este audio." },
          { type: "input_audio", input_audio: { data: Base64.strict_encode64(audio_bytes), format: format } }
        ] }
      ]

      response = with_retries do
        http_client.chat(parameters: {
          model: @model,
          modalities: [ "text" ],
          messages: messages,
          response_format: { type: "json_object" }
        })
      end

      content = response.dig("choices", 0, "message", "content").to_s.strip
      parsed  = (JSON.parse(content) rescue { "raw" => content })
      usage   = response["usage"] || {}

      Openai::PromptLogger.record(
        key: "voice_analyzer", name: "Análisis paralingüístico de voz",
        description: "Infiere tono/emoción/energía desde audio del participante.",
        system_body: ANALYSIS_INSTRUCTION,
        messages: [ { role: "system", content: ANALYSIS_INSTRUCTION } ],
        output_body: content,
        model_used: response["model"] || @model,
        tokens_input: usage["prompt_tokens"].to_i,
        tokens_output: usage["completion_tokens"].to_i,
        moment: "voice_analysis"
      )

      Result.new(
        analysis: parsed,
        prompt_used: ANALYSIS_INSTRUCTION,
        tokens_input: usage["prompt_tokens"].to_i,
        tokens_output: usage["completion_tokens"].to_i,
        model: response["model"] || @model
      )
    end

    private

    def skipped(reason)
      Result.new(analysis: {}, prompt_used: nil, tokens_input: 0, tokens_output: 0,
                 model: @model, skipped_reason: reason)
    end

    def http_client
      @http_client ||= ::OpenAI::Client.new(access_token: @api_key, request_timeout: 60)
    end

    # gpt-4o-audio-preview accepts only wav/mp3. WhatsApp voice notes are audio/ogg (opus).
    # Convert with ffmpeg when needed; skip cleanly if ffmpeg is missing.
    def ensure_supported_format(bytes, mime)
      return [ bytes, "mp3" ] if mime.to_s.include?("mpeg")
      return [ bytes, "wav" ] if mime.to_s.include?("wav")

      return nil unless ffmpeg_available?

      mp3 = transcode_to_mp3(bytes)
      mp3 ? [ mp3, "mp3" ] : nil
    end

    def ffmpeg_available?
      @ffmpeg_available ||= system("which ffmpeg > /dev/null 2>&1")
    end

    def transcode_to_mp3(bytes)
      Tempfile.open([ "wa_in", ".bin" ], binmode: true) do |input|
        input.write(bytes)
        input.flush

        output_path = "#{input.path}.mp3"
        _stdout, stderr, status = Open3.capture3(
          "ffmpeg", "-y", "-i", input.path, "-vn", "-ac", "1", "-ar", "16000",
          "-b:a", "32k", output_path
        )

        if status.success?
          File.binread(output_path)
        else
          Rails.logger.warn("ffmpeg failed: #{stderr}")
          nil
        end
      ensure
        File.unlink(output_path) if defined?(output_path) && File.exist?(output_path.to_s)
      end
    end
  end
end
