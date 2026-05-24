module Openai
  class PatternClusterer
    Result = Struct.new(:clusters, :total_reports_analyzed,
                        :tokens_input, :tokens_output, :model, keyword_init: true)

    DEFAULT_SAMPLE_SIZE = 80
    SYSTEM_KEY = "methodology_pattern_clusterer".freeze

    def initialize(program: nil, sample_size: DEFAULT_SAMPLE_SIZE, client: Openai::Client.new)
      @program     = program
      @sample_size = sample_size
      @client      = client
    end

    def call
      reports = recent_reports
      return empty_result if reports.empty?

      messages = build_messages(reports)
      response = @client.chat(
        messages: messages,
        max_tokens: 1500,
        temperature: 0.3,
        response_format: { type: "json_object" }
      )

      Openai::PromptLogger.record(
        key: SYSTEM_KEY,
        name: "Clustering de patrones de check-in",
        description: "Agrupa ai_key_pattern recurrentes en temas para la sección Metodología.",
        system_body: messages.first[:content],
        messages: messages,
        response: response,
        program: @program,
        moment: "methodology",
        latency_ms: response.latency_ms
      )

      parsed = parse(response.content)
      clusters = enrich_with_phase_distribution(parsed["clusters"] || [], reports)

      Result.new(
        clusters: clusters,
        total_reports_analyzed: reports.size,
        tokens_input: response.tokens_input,
        tokens_output: response.tokens_output,
        model: response.model
      )
    end

    private

    def recent_reports
      scope = DailyReport.where.not(ai_key_pattern: [ nil, "" ])
      if @program
        scope = scope.joins(:participant).where(participants: { program_id: @program.id })
      end
      scope.includes(:participant).order(created_at: :desc).limit(@sample_size).to_a
    end

    def build_messages(reports)
      samples = reports.map.with_index do |r, i|
        phase = r.participant&.day_content&.phase || "n/a"
        <<~SAMPLE
          [#{i}] día=#{r.day_number} fase=#{phase} pattern="#{truncate(r.ai_key_pattern, 200)}"
        SAMPLE
      end.join

      [
        { role: "system", content: <<~SYS },
          Eres un analista experto en patrones de comportamiento humano. Recibes una lista
          de patrones detectados en check-ins nocturnos de un programa de coaching de 14 días.
          Cada patrón viene con su día y fase (see/choose/anchor).

          Tu tarea:
          1. Agrupar los patrones en TEMAS recurrentes (entre 3 y 8 clusters).
          2. Para cada cluster: nombrar el tema, contar frecuencia, listar 2-4 frases ejemplo
             representativas, listar los índices [N] de los reportes que pertenecen al cluster.
          3. Ignorar outliers solitarios.

          Devuelve SOLO un JSON con esta forma estricta:
          {
            "clusters": [
              {
                "theme": "nombre corto del tema (max 60 chars)",
                "frequency": <int>,
                "sample_phrases": ["...", "..."],
                "report_indices": [0, 3, 7]
              }
            ]
          }
        SYS
        { role: "user", content: <<~USER }
          PATRONES (#{reports.size}):
          #{samples}

          Devuelve solo el JSON.
        USER
      ]
    end

    def enrich_with_phase_distribution(clusters, reports)
      clusters.filter_map do |c|
        indices = Array(c["report_indices"]).map(&:to_i).select { |i| i >= 0 && i < reports.size }
        next if indices.empty?

        slice = indices.map { |i| reports[i] }
        phase_counts = Hash.new(0)
        slice.each { |r| phase_counts[(r.participant&.day_content&.phase || "unknown").to_s] += 1 }

        {
          "theme" => c["theme"].to_s,
          "frequency" => c["frequency"].to_i.nonzero? || slice.size,
          "sample_phrases" => Array(c["sample_phrases"]).map(&:to_s).first(4),
          "phase_distribution" => phase_counts,
          "daily_report_ids" => slice.map(&:id)
        }
      end
    end

    def parse(content)
      JSON.parse(content.to_s)
    rescue JSON::ParserError => e
      Rails.logger.warn("PatternClusterer JSON parse failed: #{e.message}")
      { "clusters" => [] }
    end

    def truncate(str, n)
      str.to_s.length > n ? "#{str[0, n]}…" : str.to_s
    end

    def empty_result
      Result.new(clusters: [], total_reports_analyzed: 0,
                 tokens_input: 0, tokens_output: 0, model: nil)
    end
  end
end
