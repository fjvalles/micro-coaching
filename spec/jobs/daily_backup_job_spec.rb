require "rails_helper"

RSpec.describe DailyBackupJob, type: :job do
  it "dumps, uploads, prunes, and removes the local file" do
    tmp_path = Rails.root.join("tmp", "backups_test", "x.dump").to_s
    FileUtils.mkdir_p(File.dirname(tmp_path))
    File.write(tmp_path, "DUMP")

    dump_result = Backups::DatabaseDumper::Result.new(path: tmp_path, filename: "x.dump", byte_size: 4)
    dumper = instance_double(Backups::DatabaseDumper, call: dump_result)
    allow(Backups::DatabaseDumper).to receive(:new).and_return(dumper)

    uploader = instance_double(Backups::GoogleDriveUploader)
    expect(uploader).to receive(:upload).with(path: tmp_path, filename: "x.dump")
    expect(uploader).to receive(:prune_old)
    allow(Backups::GoogleDriveUploader).to receive(:new).and_return(uploader)

    described_class.new.perform

    expect(File.exist?(tmp_path)).to be false
  end

  it "still removes the local file when upload raises" do
    tmp_path = Rails.root.join("tmp", "backups_test", "y.dump").to_s
    FileUtils.mkdir_p(File.dirname(tmp_path))
    File.write(tmp_path, "DUMP")

    dump_result = Backups::DatabaseDumper::Result.new(path: tmp_path, filename: "y.dump", byte_size: 4)
    allow(Backups::DatabaseDumper).to receive(:new).and_return(instance_double(Backups::DatabaseDumper, call: dump_result))

    uploader = instance_double(Backups::GoogleDriveUploader)
    allow(uploader).to receive(:upload).and_raise(Backups::UploadError, "fail")
    allow(Backups::GoogleDriveUploader).to receive(:new).and_return(uploader)

    expect { described_class.new.perform }.to raise_error(Backups::UploadError)
    expect(File.exist?(tmp_path)).to be false
  end
end
