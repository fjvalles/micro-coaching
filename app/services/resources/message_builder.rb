module Resources
  class MessageBuilder
    URL_PATTERN = %r{https?://[^\s<>()]+}i

    Result = Struct.new(:body, :resource, :preview_url, keyword_init: true)

    def initialize(body:, resource_id:, program:)
      @body = body.to_s
      @resource_id = resource_id.to_s
      @program = program
    end

    def call
      resource = find_resource
      sanitized = strip_urls(@body)

      unless resource
        log_rejected_url if @body.match?(URL_PATTERN) || @resource_id.present?
        return Result.new(body: sanitized, resource: nil, preview_url: false)
      end

      final_body = [ sanitized, resource.url ].reject(&:blank?).join("\n\n")
      Result.new(
        body: final_body,
        resource: resource,
        preview_url: Setting.fetch("link_preview_enabled")
      )
    end

    private

    def find_resource
      return nil if @resource_id.blank?
      return nil unless Setting.fetch("resource_catalog_enabled")

      Resource.sendable.for_program(@program).find_by(id: @resource_id)
    end

    def strip_urls(text)
      text.gsub(URL_PATTERN, "").squish
    end

    def log_rejected_url
      Rails.logger.warn(
        "Resources::MessageBuilder rejected resource_id=#{@resource_id.presence || '(none)'}"
      )
    end
  end
end
