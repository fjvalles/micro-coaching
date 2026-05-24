class DailyBackupJob < ApplicationJob
  queue_as :default

  def perform
    dump = Backups::DatabaseDumper.new.call
    uploader = Backups::GoogleDriveUploader.new
    uploader.upload(path: dump.path, filename: dump.filename)
    uploader.prune_old
  ensure
    File.delete(dump.path) if dump&.path && File.exist?(dump.path)
  end
end
