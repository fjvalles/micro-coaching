module Openai
  class PromptCritic
    Result = Struct.new(:analysis, :findings, :suggested_body, :rationale,
                        :tokens_input, :tokens_output, :model, keyword_init: true)

    SAMPLE_SIZE = 20

    def initialize(template:, sample_size: SAMPLE_SIZE, client: Openai::Client.new)
      @template = template
      @sample_size = sample_size
      @client = client
    end

    def call
      executions = @template.prompt_executions.recent.limit(@sample_size).to_a
      messages = build_messages(executions)
      response = @client.chat(
        messages: messages,
        max_tokens: 1200,
        temperature: 0.3,
        response_format: { type: "json_object" }
      )
      parsed = parse(response.content)

      analysis = @template.prompt_analyses.create!(
        prompt_version: @template.latest_version,
        executions_sampled: executions.size,
        findings: parsed["findings"] || {},
        suggested_body: parsed["suggested_body"],
        rationale: parsed["rationale"],
        model_used: response.model,
        tokens_input: response.tokens_input,
        tokens_output: response.tokens_output
      )

      Result.new(
        analysis: analysis,
        findings: analysis.findings,
        suggested_body: analysis.suggested_body,
        rationale: analysis.rationale,
        tokens_input: response.tokens_input,
        tokens_output: response.tokens_output,
        model: response.model
      )
    end

    private

    def build_messages(executions)
      samples = executions.map.with_index do |e, i|
        <<~SAMPLE
          --- Ejemplo #{i + 1} (día #{e.day_number || 'n/a'}, momento #{e.moment || 'n/a'}) ---
          INPUT_MESSAGES:
          #{truncate(e.rendered_messages.to_json, 1500)}
          OUTPUT:
          #{truncate(e.output_body.to_s, 600)}
          TOKENS_IN=#{e.tokens_input} TOKENS_OUT=#{e.tokens_output} LAT_MS=#{e.latency_ms}
        SAMPLE
      end.join("\n")

      [
        { role: "system", content: <<~SYS },
          Eres un experto en ingeniería de prompts para un programa de coaching conductual
          en español. Recibes el system-prompt actual de una sección + ejemplos reales de
          ejecuciones (input renderizado, output del modelo, tokens). Tu trabajo:
          1. Detectar debilidades del prompt actual (vaguedad, instrucciones redundantes,
             formato inestable, falta de constraints, longitud excesiva, etc.).
          2. Proponer una versión mejorada del system-prompt.
          3. Justificar brevemente.

          Devuelve SOLO un JSON con esta forma:
          {
            "findings": {
              "strengths": ["..."],
              "weaknesses": ["..."],
              "risks": ["..."]
            },
            "suggested_body": "nuevo system prompt completo",
            "rationale": "por qué los cambios mejoran outputs"
          }
        SYS
        { role: "user", content: <<~USER }
          SECCIÓN: #{@template.key} (#{@template.label})
          DESCRIPCIÓN: #{@template.description}
          VERSIÓN ACTUAL (v#{@template.current_version}):
          ---
          #{@template.current_body}
          ---

          EJECUCIONES RECIENTES (#{executions.size}):
          #{samples.presence || '(sin ejemplos)'}
        USER
      ]
    end

    def parse(content)
      JSON.parse(content.to_s)
    rescue JSON::ParserError
      { "findings" => { "raw" => content.to_s }, "suggested_body" => nil, "rationale" => nil }
    end

    def truncate(str, n)
      str.to_s.length > n ? "#{str[0, n]}…" : str
    end
  end
end
