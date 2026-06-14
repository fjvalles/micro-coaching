require "set"

module Resources
  class Finder
    Result = Struct.new(:resources, :error, keyword_init: true) do
      def ok? = error.blank?
    end

    def initialize(topic:, kind:, program: nil, source: :gap_detection, client: Openai::Client.new)
      @topic = topic.to_s.strip
      @kind = kind.to_s
      @program = program
      @source = source.to_s
      @client = client
    end

    def call
      return Result.new(resources: [], error: "topic blank") if @topic.blank?
      return Result.new(resources: [], error: "invalid kind") unless Resource.kinds.key?(@kind)

      response = @client.chat(
        messages: messages,
        max_tokens: Setting.fetch("openai_max_tokens_resource_finder"),
        temperature: Setting.fetch("openai_temperature_json"),
        response_format: { type: "json_object" },
        task: :resource_finder
      )

      resources = candidates_from(response).filter_map { |candidate| persist(candidate) }
      Result.new(resources: resources)
    rescue JSON::ParserError => e
      Result.new(resources: [], error: e.message)
    end

    private

    def messages
      [
        { role: "system", content: system_prompt },
        { role: "user", content: "Busca hasta #{max_candidates} recursos #{kind_label} sobre: #{@topic}" }
      ]
    end

    def system_prompt
      <<~PROMPT
        Eres un buscador de recursos para un programa de coaching conductual.
        Usa búsqueda web real y responde JSON estricto:
        {"candidates":[{"title":"...","url":"...","snippet":"..."}]}
        No inventes URLs. Solo incluye URLs que provengan de citaciones de búsqueda.
      PROMPT
    end

    def kind_label
      @kind == "video" ? "en video" : "en artículo"
    end

    def max_candidates
      Setting.fetch("resource_finder_max_candidates").to_i.clamp(1, 10)
    end

    def candidates_from(response)
      cited_urls = cited_urls_from(response)
      parsed = JSON.parse(response.content)
      Array(parsed["candidates"]).first(max_candidates).select do |candidate|
        cited_urls.include?(normalized_url(candidate["url"]))
      end
    end

    def cited_urls_from(response)
      Array(response.annotations).filter_map do |annotation|
        citation = annotation["url_citation"] || annotation[:url_citation] || annotation
        normalized_url(citation["url"] || citation[:url])
      end.to_set
    end

    def normalized_url(url)
      url.to_s.strip
    end

    def persist(candidate)
      Resource.create_with(
        title: candidate["title"].to_s.truncate(255).presence || @topic.truncate(80),
        kind: @kind,
        status: :pending,
        source: @source,
        description: candidate["snippet"],
        topics: [ @topic ],
        program: @program
      ).find_or_create_by!(url: normalized_url(candidate["url"]))
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Rails.logger.warn("Resources::Finder skipped candidate: #{e.message}")
      nil
    end
  end
end
