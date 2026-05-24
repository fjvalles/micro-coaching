require "rails_helper"

RSpec.describe Backups::DatabaseDumper do
  let(:tmp_dir) { Rails.root.join("tmp", "backups_test") }

  after { FileUtils.rm_rf(tmp_dir) }

  it "invokes pg_dump and returns the dump file path" do
    fake_status = instance_double(Process::Status, success?: true)

    expect(Open3).to receive(:capture3) do |*cmd|
      expect(cmd.first).to eq("pg_dump")
      path = cmd.find { |a| a.to_s.start_with?("--file=") }.split("=", 2).last
      File.write(path, "PGDUMPBYTES")
      [ "", "", fake_status ]
    end

    result = described_class.new(output_dir: tmp_dir, timestamp: Time.utc(2026, 1, 2, 3, 4, 5)).call

    expect(result.filename).to eq("impulso-test-20260102T030405Z.dump")
    expect(File.exist?(result.path)).to be true
    expect(result.byte_size).to eq("PGDUMPBYTES".bytesize)
  end

  it "raises DumpError when pg_dump fails" do
    fake_status = instance_double(Process::Status, success?: false)
    allow(Open3).to receive(:capture3).and_return([ "", "boom", fake_status ])

    expect { described_class.new(output_dir: tmp_dir).call }.to raise_error(Backups::DumpError, /boom/)
  end

  it "raises DumpError when pg_dump produces empty file" do
    fake_status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3) do |*cmd|
      path = cmd.find { |a| a.to_s.start_with?("--file=") }.split("=", 2).last
      File.write(path, "")
      [ "", "", fake_status ]
    end

    expect { described_class.new(output_dir: tmp_dir).call }.to raise_error(Backups::DumpError, /empty/)
  end
end
