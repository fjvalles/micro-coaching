require "rails_helper"

RSpec.describe Backups::S3Uploader do
  let(:uploader) do
    described_class.new(
      access_key_id: "fake_access",
      secret_access_key: "fake_secret",
      region: "us-east-005",
      endpoint: "https://s3.us-east-005.backblazeb2.com",
      bucket: "test-bucket",
      retention_days: 7
    )
  end

  let(:s3_resource) { instance_double(Aws::S3::Resource) }
  let(:bucket) { instance_double(Aws::S3::Bucket) }

  before do
    allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
    allow(s3_resource).to receive(:bucket).with("test-bucket").and_return(bucket)
  end

  describe "#upload" do
    let(:s3_object) { instance_double(Aws::S3::Object) }

    it "uploads the file to the bucket" do
      allow(bucket).to receive(:object).with("test.dump").and_return(s3_object)
      expect(s3_object).to receive(:put)

      result = uploader.upload(path: "/tmp/test.dump", filename: "test.dump")
      expect(result).to eq(s3_object)
    end
  end

  describe "#prune_old" do
    let(:recent_obj) { instance_double(Aws::S3::ObjectSummary, key: "recent.dump", last_modified: 2.days.ago) }
    let(:old_obj) { instance_double(Aws::S3::ObjectSummary, key: "old.dump", last_modified: 8.days.ago) }
    
    # We must mock #delete on the ObjectSummary (or the Object it resolves to, but standard SDK allows delete on summary)
    let(:recent_obj_instance) { instance_double(Aws::S3::Object) }
    let(:old_obj_instance) { instance_double(Aws::S3::Object) }

    it "deletes files older than retention days" do
      allow(bucket).to receive(:objects).and_return([recent_obj, old_obj])
      
      expect(recent_obj).not_to receive(:delete)
      expect(old_obj).to receive(:delete)

      deleted = uploader.prune_old
      expect(deleted).to eq(["old.dump"])
    end
  end
end
