module Guardrails
  class Validator
    Result = Struct.new(:valid, :errors, keyword_init: true) do
      def valid? = valid
    end

    URL = %r{https?://|www\.}i
    EMAIL = /[\w.+-]+@[\w-]+\.[\w.-]+/
    PHONE = /\+?\d[\d\s\-().]{7,16}\d/
    CONTRADICTIONS = [
      /ignora .*system prompt/i,
      /revela .*prompt/i,
      /entrega .*datos/i,
      /metodolog[ií]a interna/i,
      /preguntas futuras/i,
      /datos personales/i
    ].freeze

    def initialize(current_guardrails:, proposed_guardrails:, forbidden_terms: [])
      @current_guardrails = current_guardrails.to_s
      @proposed_guardrails = proposed_guardrails.to_s
      @forbidden_terms = Array(forbidden_terms).map { |term| term.to_s.strip }.reject(&:blank?)
    end

    def call
      errors = []
      errors << "no puede estar vacío" if @proposed_guardrails.blank?
      errors << "supera el largo máximo" if @proposed_guardrails.length > Setting.fetch("auto_tuning_max_guardrails_chars").to_i
      errors << "debe conservar la regla de una sola pregunta" unless includes_single_question_anchor?
      errors << "debe conservar la regla de autonomía/no insistencia" unless includes_autonomy_anchor?
      errors << "no puede incluir URLs" if @proposed_guardrails.match?(URL)
      errors << "no puede incluir emails" if @proposed_guardrails.match?(EMAIL)
      errors << "no puede incluir teléfonos" if @proposed_guardrails.match?(PHONE)
      errors << "no puede contradecir el bloque de seguridad" if contradicts_security_block?
      errors << "cambia demasiado del bloque actual" if rewrite_ratio > 0.45
      errors << "no puede incluir nombres propios de participantes" if includes_forbidden_term?

      Result.new(valid: errors.empty?, errors: errors)
    end

    private

    def includes_single_question_anchor?
      @proposed_guardrails.match?(/una sola pregunta|1 pregunta|nunca dos preguntas/i)
    end

    def includes_autonomy_anchor?
      @proposed_guardrails.match?(/autonom[ií]a|no insistas|respeta/i)
    end

    def contradicts_security_block?
      CONTRADICTIONS.any? { |pattern| @proposed_guardrails.match?(pattern) }
    end

    def includes_forbidden_term?
      @forbidden_terms.any? { |term| @proposed_guardrails.downcase.include?(term.downcase) }
    end

    def rewrite_ratio
      return 1.0 if @current_guardrails.blank? && @proposed_guardrails.present?
      return 0.0 if @current_guardrails == @proposed_guardrails

      current_words = @current_guardrails.scan(/\p{Alnum}+/).map(&:downcase)
      proposed_words = @proposed_guardrails.scan(/\p{Alnum}+/).map(&:downcase)
      return 1.0 if current_words.empty?

      common = (current_words & proposed_words).size
      1.0 - (common.to_f / current_words.uniq.size)
    end
  end
end
