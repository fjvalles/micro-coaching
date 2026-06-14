module Whatsapp
  class InboundParser
    Message = Struct.new(:from, :wamid, :type, :text, :media_id, :timestamp, :profile_name, keyword_init: true)
    Status  = Struct.new(:wamid, :status, :timestamp, :recipient, keyword_init: true)

    def self.parse(payload)
      new(payload).parse
    end

    def initialize(payload)
      @payload = payload.is_a?(String) ? (JSON.parse(payload) rescue {}) : (payload || {})
      @payload = {} unless @payload.is_a?(Hash)
    end

    def parse
      { messages: messages, statuses: statuses }
    rescue JSON::ParserError, NoMethodError
      { messages: [], statuses: [] }
    end

    private

    def entries
      @payload.fetch("entry", [])
    end

    def messages
      entries.flat_map do |entry|
        entry.fetch("changes", []).flat_map do |change|
          names = contact_names(change)
          (change.dig("value", "messages") || []).map { |m| build_message(m, names) }
        end
      end.compact
    end

    # Maps wa_id → WhatsApp profile name from the webhook's contacts block.
    # Used by WhatsApp-first self-signup to name a brand-new participant.
    def contact_names(change)
      (change.dig("value", "contacts") || []).each_with_object({}) do |c, h|
        wa_id = c["wa_id"]
        name = c.dig("profile", "name")
        h[wa_id] = name if wa_id && name.present?
      end
    end

    def statuses
      entries.flat_map do |entry|
        entry.fetch("changes", []).flat_map do |change|
          (change.dig("value", "statuses") || []).map { |s| build_status(s) }
        end
      end.compact
    end

    def build_message(m, names = {})
      type = m["type"]
      text = case type
             when "text" then m.dig("text", "body")
             when "button" then m.dig("button", "text")
             when "interactive" then m.dig("interactive", "button_reply", "title") || m.dig("interactive", "list_reply", "title")
             end
      media_id = m.dig(type, "id") if %w[image audio video document voice].include?(type)

      Message.new(
        from: m["from"],
        wamid: m["id"],
        type: type,
        text: text,
        media_id: media_id,
        timestamp: m["timestamp"],
        profile_name: names[m["from"]]
      )
    end

    def build_status(s)
      Status.new(
        wamid: s["id"],
        status: s["status"],
        timestamp: s["timestamp"],
        recipient: s["recipient_id"]
      )
    end
  end
end
