module Whatsapp
  class TemplateBodySanitizer
    SIGNATURE_PATTERN = /\n+\s*(?:[-–—]\s*)?(?:Impulso Coach|Coach Impulso|Impulso)\s*\z/i
    GREETING_WORDS = "(?:muy\\s+)?(?:buenos\\s+d[ií]as|buen\\s+d[ií]a|buenas\\s+tardes|buenas\\s+noches|hola)"

    def self.call(body, participant_name: nil)
      new(body, participant_name: participant_name).call
    end

    def initialize(body, participant_name: nil)
      @body = body
      @participant_name = participant_name.to_s.strip
    end

    def call
      text = @body.to_s.strip
      text = strip_opening_greeting(text)
      text = strip_trailing_signature(text)
      text.presence || @body.to_s.strip
    end

    private

    def strip_opening_greeting(text)
      strip_participant_name(strip_generic_greeting(text))
    end

    def strip_generic_greeting(text)
      return text if @participant_name.blank?

      name = Regexp.escape(@participant_name)
      text.sub(/\A[¡!]*\s*#{GREETING_WORDS}\s*,?\s*#{name}\s*[.!,:;–-]*\s*/i, "")
          .sub(/\A[¡!]*\s*#{GREETING_WORDS}\s*[.!,:;–-]+\s*/i, "")
    end

    def strip_participant_name(text)
      return text if @participant_name.blank?

      name = Regexp.escape(@participant_name)
      text.sub(/\A\s*#{name}\s*[.!,:;–-]+\s*/i, "")
    end

    def strip_trailing_signature(text)
      text.sub(SIGNATURE_PATTERN, "").strip
    end
  end
end
