require "net/http"
require "digest"

module Whatsapp
  class MediaFetcher
    Result = Struct.new(:bytes, :mime_type, :byte_size, :sha256, :filename, keyword_init: true)
    class Error < StandardError; end

    BASE = "https://graph.facebook.com".freeze

    def initialize(media_id:, api_version: nil, access_token: nil)
      @media_id     = media_id
      @api_version  = api_version || Setting.fetch("meta_api_version").presence ||
                      ENV.fetch("META_API_VERSION", "v25.0")
      @access_token = access_token || ENV.fetch("META_ACCESS_TOKEN")
    end

    def call
      url, mime = fetch_metadata
      bytes = download(url)
      Result.new(
        bytes: bytes,
        mime_type: mime,
        byte_size: bytes.bytesize,
        sha256: Digest::SHA256.hexdigest(bytes),
        filename: filename_for(mime)
      )
    end

    private

    def fetch_metadata
      uri = URI("#{BASE}/#{@api_version}/#{@media_id}")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{@access_token}"
      resp = http(uri).request(req)
      raise Error, "metadata #{resp.code}: #{resp.body}" unless resp.code.to_i.between?(200, 299)

      parsed = JSON.parse(resp.body)
      url = parsed["url"] or raise Error, "no media url in metadata: #{parsed.inspect}"
      [ url, parsed["mime_type"] ]
    end

    def download(url)
      uri = URI(url)
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{@access_token}"
      resp = http(uri).request(req)
      raise Error, "download #{resp.code}" unless resp.code.to_i.between?(200, 299)
      resp.body
    end

    def http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.read_timeout = 30
      http
    end

    def filename_for(mime)
      ext = case mime.to_s
      when /ogg/  then "ogg"
      when /mpeg/ then "mp3"
      when /mp4/  then "m4a"
      when /wav/  then "wav"
      when /webm/ then "webm"
      else             "ogg"
      end
      "wa_audio_#{@media_id}.#{ext}"
    end
  end
end
