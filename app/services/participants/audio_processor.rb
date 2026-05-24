module Participants
  class AudioProcessor
    Result = Struct.new(:transcription, :voice_analysis, :too_long, :error, keyword_init: true)

    def initialize(conversation:, media_id:)
      @conversation = conversation
      @media_id = media_id
    end

    def call
      media = Whatsapp::MediaFetcher.new(media_id: @media_id).call

      transcription = Openai::AudioTranscriber.new(
        bytes: media.bytes, filename: media.filename, mime_type: media.mime_type
      ).call

      duration = transcription.duration&.to_f

      if duration && duration > Setting.fetch("audio_max_duration_seconds").to_i
        @conversation.update!(
          media_id: @media_id,
          media_mime_type: media.mime_type,
          audio_duration_seconds: duration.to_i,
          transcription: transcription.text
        )
        return Result.new(transcription: transcription.text, too_long: true)
      end

      analysis = Openai::VoiceAnalyzer.new(
        bytes: media.bytes, mime_type: media.mime_type
      ).call

      @conversation.update!(
        media_id: @media_id,
        media_mime_type: media.mime_type,
        audio_duration_seconds: duration&.to_i,
        transcription: transcription.text,
        voice_analysis: analysis.analysis.merge(
          "_meta" => {
            "model" => analysis.model,
            "tokens_input" => analysis.tokens_input,
            "tokens_output" => analysis.tokens_output,
            "skipped_reason" => analysis.skipped_reason
          }.compact
        ),
        body: transcription.text,
        tokens_input: (@conversation.tokens_input.to_i + analysis.tokens_input.to_i),
        tokens_output: (@conversation.tokens_output.to_i + analysis.tokens_output.to_i)
      )

      Result.new(transcription: transcription.text, voice_analysis: analysis.analysis)
    rescue Whatsapp::MediaFetcher::Error, StandardError => e
      Rails.logger.error("AudioProcessor error: #{e.class}: #{e.message}")
      @conversation.update(error_message: "audio: #{e.class}: #{e.message}")
      Result.new(error: e.message)
    end
  end
end
