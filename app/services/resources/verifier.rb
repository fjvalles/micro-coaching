require "ipaddr"
require "net/http"
require "resolv"

module Resources
  class Verifier
    Result = Struct.new(:resource, :ok, :error, keyword_init: true) do
      def ok? = ok
    end

    MAX_REDIRECTS = 3
    MAX_CONTENT_BYTES = 80_000
    PRIVATE_RANGES = [
      IPAddr.new("10.0.0.0/8"),
      IPAddr.new("127.0.0.0/8"),
      IPAddr.new("169.254.0.0/16"),
      IPAddr.new("172.16.0.0/12"),
      IPAddr.new("192.168.0.0/16"),
      IPAddr.new("::1/128"),
      IPAddr.new("fc00::/7"),
      IPAddr.new("fe80::/10")
    ].freeze

    def initialize(resource:, topic: nil, client: Openai::Client.new)
      @resource = resource
      @topic = topic.presence || Array(resource.topics).join(", ")
      @client = client
    end

    def call
      uri = validated_uri(@resource.url)
      page = fetch_page(uri)
      judge = judge_content(page)

      if page[:status].between?(200, 299) && judge[:match]
        mark_verified(page, judge)
      else
        mark_rejected(page, judge)
      end
    rescue ArgumentError => e
      mark_rejected({ status: nil, final_url: @resource.url }, match: false, reason: e.message)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      mark_rejected({ status: nil, final_url: @resource.url }, match: false, reason: e.message)
    end

    private

    def validated_uri(url)
      uri = URI.parse(url.to_s)
      raise ArgumentError, "URL inválida" unless uri.is_a?(URI::HTTP) && uri.host.present?
      raise ArgumentError, "solo se permiten URLs http/https" unless %w[http https].include?(uri.scheme)

      validate_public_host!(uri.host)
      uri
    rescue URI::InvalidURIError
      raise ArgumentError, "URL inválida"
    end

    def validate_public_host!(host)
      addresses = Resolv.getaddresses(host)
      raise ArgumentError, "host no resolvible" if addresses.empty?

      addresses.each do |address|
        ip = IPAddr.new(address)
        raise ArgumentError, "host privado bloqueado" if PRIVATE_RANGES.any? { |range| range.include?(ip) }
      end
    end

    def fetch_page(uri, redirects = 0)
      raise ArgumentError, "demasiados redirects" if redirects > MAX_REDIRECTS

      response = request(uri)
      if response.is_a?(Net::HTTPRedirection)
        location = response["location"].to_s
        next_uri = validated_uri(URI.join(uri, location).to_s)
        return fetch_page(next_uri, redirects + 1)
      end

      {
        status: response.code.to_i,
        final_url: uri.to_s,
        title: extract_title(response.body.to_s),
        description: extract_description(response.body.to_s),
        body_preview: response.body.to_s.byteslice(0, MAX_CONTENT_BYTES)
      }
    end

    def request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 8

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "ImpulsoResourceVerifier/1.0"
      http.request(request)
    end

    def judge_content(page)
      return { match: false, reason: "HTTP #{page[:status]}" } unless page[:status].between?(200, 299)
      return { match: true, reason: "sin tema declarado" } if @topic.blank?

      messages = [
        { role: "system", content: judge_system_prompt },
        { role: "user", content: judge_user_prompt(page) }
      ]
      response = @client.chat(
        messages: messages,
        max_tokens: 220,
        temperature: Setting.fetch("openai_temperature_json"),
        response_format: { type: "json_object" },
        task: :resource_verifier
      )

      Openai::PromptLogger.record(
        key: "resource_verifier", name: "Verificador de recurso",
        description: "Valida que una URL corresponda al tema declarado del recurso.",
        system_body: judge_system_prompt, messages: messages, response: response,
        program: @resource.program, day_number: nil, moment: "resource_verifier",
        latency_ms: response.latency_ms
      )

      parsed = JSON.parse(response.content)
      { match: ActiveModel::Type::Boolean.new.cast(parsed["match"]), reason: parsed["reason"].to_s }
    rescue JSON::ParserError => e
      { match: false, reason: "respuesta inválida del juez: #{e.message}" }
    end

    def judge_system_prompt
      <<~PROMPT
        Eres un verificador de recursos para un programa de coaching.
        Responde solo JSON: {"match": boolean, "reason": "breve"}.
        Marca match=true solo si el contenido trata claramente del tema declarado
        y es apropiado para un participante adulto de coaching conductual.
      PROMPT
    end

    def judge_user_prompt(page)
      <<~PROMPT
        Tema declarado: #{@topic}
        Tipo: #{@resource.kind}
        Título: #{page[:title]}
        Descripción: #{page[:description]}
        URL final: #{page[:final_url]}
      PROMPT
    end

    def extract_title(html)
      html[%r{<title[^>]*>(.*?)</title>}im, 1].to_s.squish.truncate(250)
    end

    def extract_description(html)
      html[%r{<meta[^>]+name=["']description["'][^>]+content=["'](.*?)["']}im, 1].to_s.squish.truncate(500)
    end

    def mark_verified(page, judge)
      @resource.update!(
        status: verified_status,
        last_verified_at: Time.current,
        verification: verification_payload(page, judge)
      )
      Result.new(resource: @resource, ok: true)
    end

    def mark_rejected(page, judge)
      status = page[:status].to_i == 404 ? :dead : :rejected
      @resource.update!(
        status: status,
        last_verified_at: Time.current,
        verification: verification_payload(page, judge)
      )
      Result.new(resource: @resource, ok: false, error: judge[:reason])
    end

    def verification_payload(page, judge)
      {
        http_status: page[:status],
        final_url: page[:final_url],
        content_match: judge[:match],
        judge_reason: judge[:reason]
      }
    end

    def verified_status
      return :approved if @resource.approved?
      return :approved unless Setting.fetch("resource_review_required")

      :verified
    end
  end
end
