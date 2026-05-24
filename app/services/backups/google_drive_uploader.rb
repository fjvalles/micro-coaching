require "google/apis/drive_v3"
require "googleauth"
require "stringio"

module Backups
  class UploadError < StandardError; end

  class GoogleDriveUploader
    SCOPE = "https://www.googleapis.com/auth/drive.file".freeze
    RETENTION_DAYS = 7

    def initialize(folder_id: ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"],
                   credentials_json: ENV["GOOGLE_SERVICE_ACCOUNT_JSON"],
                   retention_days: RETENTION_DAYS)
      @folder_id = folder_id
      @credentials_json = credentials_json
      @retention_days = retention_days
    end

    def upload(path:, filename:)
      raise UploadError, "GOOGLE_DRIVE_BACKUP_FOLDER_ID missing" if @folder_id.blank?
      raise UploadError, "GOOGLE_SERVICE_ACCOUNT_JSON missing" if @credentials_json.blank?

      metadata = Google::Apis::DriveV3::File.new(name: filename, parents: [ @folder_id ])
      file = service.create_file(metadata, upload_source: path, content_type: "application/octet-stream", fields: "id, name, createdTime")
      Rails.logger.info("[Backups] uploaded #{file.name} (#{file.id})")
      file
    end

    def prune_old
      cutoff = @retention_days.days.ago
      list = service.list_files(
        q: "'#{@folder_id}' in parents and trashed = false",
        fields: "files(id, name, createdTime)",
        page_size: 100
      )
      deleted = []
      Array(list.files).each do |f|
        next unless f.created_time && f.created_time < cutoff
        service.delete_file(f.id)
        deleted << f.name
      end
      Rails.logger.info("[Backups] pruned #{deleted.size} old backup(s): #{deleted.join(', ')}") if deleted.any?
      deleted
    end

    private

    def service
      @service ||= begin
        auth = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(@credentials_json),
          scope: SCOPE
        )
        drive = Google::Apis::DriveV3::DriveService.new
        drive.client_options.application_name = "Impulso Backups"
        drive.authorization = auth
        drive
      end
    end
  end
end
