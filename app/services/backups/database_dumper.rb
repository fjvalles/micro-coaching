require "open3"

module Backups
  class DumpError < StandardError; end

  class DatabaseDumper
    Result = Struct.new(:path, :filename, :byte_size, keyword_init: true)

    def initialize(timestamp: Time.current, output_dir: Rails.root.join("tmp", "backups"))
      @timestamp = timestamp
      @output_dir = output_dir
    end

    def call
      FileUtils.mkdir_p(@output_dir)
      filename = "impulso-#{Rails.env}-#{@timestamp.utc.strftime('%Y%m%dT%H%M%SZ')}.dump"
      path = File.join(@output_dir, filename)

      cmd = [ "pg_dump", "--format=custom", "--no-owner", "--no-acl", "--file=#{path}", connection_string ]
      _stdout, stderr, status = Open3.capture3(*cmd)

      raise DumpError, "pg_dump failed: #{stderr.strip}" unless status.success?
      raise DumpError, "pg_dump produced empty file" unless File.exist?(path) && File.size(path).positive?

      Result.new(path: path, filename: filename, byte_size: File.size(path))
    end

    private

    def connection_string
      cfg = ActiveRecord::Base.connection_db_config.configuration_hash
      if (url = cfg[:url] || ENV["DATABASE_URL"])
        return url
      end

      host = cfg[:host] || "localhost"
      port = cfg[:port] || 5432
      user = cfg[:username] || ENV["USER"]
      db   = cfg[:database]
      password = cfg[:password]

      auth = user.to_s
      auth = "#{auth}:#{password}" if password.present?
      auth = "#{auth}@" if auth.present?

      "postgres://#{auth}#{host}:#{port}/#{db}"
    end
  end
end
