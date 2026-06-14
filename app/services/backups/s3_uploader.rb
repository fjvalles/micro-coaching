module Backups
  class UploadError < StandardError; end

  class S3Uploader
    RETENTION_DAYS = 7

    def initialize(
      access_key_id: ENV["BACKUP_S3_ACCESS_KEY_ID"],
      secret_access_key: ENV["BACKUP_S3_SECRET_ACCESS_KEY"],
      region: ENV["BACKUP_S3_REGION"],
      endpoint: ENV["BACKUP_S3_ENDPOINT"],
      bucket: ENV["BACKUP_S3_BUCKET"],
      retention_days: RETENTION_DAYS
    )
      @access_key_id = access_key_id
      @secret_access_key = secret_access_key
      @region = region
      @endpoint = endpoint
      @bucket_name = bucket
      @retention_days = retention_days
    end

    def upload(path:, filename:)
      raise UploadError, "Missing S3 credentials or bucket" if @access_key_id.blank? || @bucket_name.blank?

      obj = resource.bucket(@bucket_name).object(filename)
      File.open(path, 'rb') do |file|
        obj.put(body: file)
      end
      Rails.logger.info("[Backups] uploaded #{filename} to S3/B2")
      obj
    end

    def prune_old
      cutoff = @retention_days.days.ago
      bucket = resource.bucket(@bucket_name)
      
      deleted = []
      bucket.objects.each do |obj|
        if obj.last_modified && obj.last_modified < cutoff
          obj.delete
          deleted << obj.key
        end
      end
      
      Rails.logger.info("[Backups] pruned #{deleted.size} old backup(s): #{deleted.join(', ')}") if deleted.any?
      deleted
    end

    private

    def resource
      @resource ||= begin
        # aws-sdk-s3 is loaded by the autoloader, but if called outside rails context we require it
        require "aws-sdk-s3" unless defined?(Aws::S3::Resource)
        Aws::S3::Resource.new(
          access_key_id: @access_key_id,
          secret_access_key: @secret_access_key,
          region: @region,
          endpoint: @endpoint
        )
      end
    end
  end
end
