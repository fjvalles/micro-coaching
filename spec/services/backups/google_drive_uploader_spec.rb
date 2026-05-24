require "rails_helper"

RSpec.describe Backups::GoogleDriveUploader do
  let(:folder_id) { "FOLDER_X" }
  let(:creds) { '{"type":"service_account","client_email":"x@y.iam"}' }
  let(:fake_drive) { instance_double(Google::Apis::DriveV3::DriveService) }

  subject(:uploader) { described_class.new(folder_id: folder_id, credentials_json: creds, retention_days: 7) }

  before do
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(double("auth"))
    allow(Google::Apis::DriveV3::DriveService).to receive(:new).and_return(fake_drive)
    allow(fake_drive).to receive(:client_options).and_return(double("application_name=": nil).as_null_object)
    allow(fake_drive).to receive(:authorization=)
  end

  describe "#upload" do
    it "creates the file inside the configured folder" do
      created = Google::Apis::DriveV3::File.new(id: "FID", name: "x.dump")
      expect(fake_drive).to receive(:create_file) do |metadata, upload_source:, content_type:, fields:|
        expect(metadata.name).to eq("x.dump")
        expect(metadata.parents).to eq([ folder_id ])
        expect(upload_source).to eq("/tmp/x.dump")
        created
      end

      expect(uploader.upload(path: "/tmp/x.dump", filename: "x.dump")).to eq(created)
    end

    it "raises when folder id missing" do
      u = described_class.new(folder_id: nil, credentials_json: creds)
      expect { u.upload(path: "/tmp/x", filename: "x") }.to raise_error(Backups::UploadError, /FOLDER_ID/)
    end

    it "raises when credentials missing" do
      u = described_class.new(folder_id: folder_id, credentials_json: nil)
      expect { u.upload(path: "/tmp/x", filename: "x") }.to raise_error(Backups::UploadError, /SERVICE_ACCOUNT/)
    end
  end

  describe "#prune_old" do
    it "deletes only files older than retention window" do
      old = Google::Apis::DriveV3::File.new(id: "OLD", name: "old.dump", created_time: 10.days.ago)
      fresh = Google::Apis::DriveV3::File.new(id: "FRESH", name: "fresh.dump", created_time: 1.day.ago)
      list = Google::Apis::DriveV3::FileList.new(files: [ old, fresh ])

      expect(fake_drive).to receive(:list_files).and_return(list)
      expect(fake_drive).to receive(:delete_file).with("OLD")
      expect(fake_drive).not_to receive(:delete_file).with("FRESH")

      expect(uploader.prune_old).to eq([ "old.dump" ])
    end

    it "handles empty folder" do
      expect(fake_drive).to receive(:list_files).and_return(Google::Apis::DriveV3::FileList.new(files: []))
      expect(uploader.prune_old).to eq([])
    end
  end
end
