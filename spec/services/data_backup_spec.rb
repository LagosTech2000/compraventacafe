require "rails_helper"

RSpec.describe DataBackup do
  let(:now) { Time.zone.local(2026, 10, 12, 15, 30) }

  def entries(path)
    Zip::File.open(path) { |zip| zip.entries.to_h { |entry| [ entry.name, entry.get_input_stream.read ] } }
  end

  it "zips one folder with the database dump, a CSV per table without secrets, and a readme" do
    create(:user, email_address: "admin@example.com")
    create(:producer)
    backup = described_class.new(now:)
    path = backup.write
    files = entries(path)
    folder = "respaldo-2026-10-12-1530"

    expect(files.keys).to include("#{folder}/base.dump", "#{folder}/LEEME.txt", "#{folder}/csv/purchases.csv", "#{folder}/csv/producers.csv")
    expect(files.keys).not_to include("#{folder}/csv/sessions.csv", "#{folder}/csv/schema_migrations.csv")

    users = files["#{folder}/csv/users.csv"].force_encoding("UTF-8")
    expect(users).to start_with("﻿").and include("admin@example.com")
    expect(users).not_to include("password_digest")

    dump = File.join(Dir.mktmpdir, "base.dump")
    File.binwrite(dump, files["#{folder}/base.dump"])
    listing, status = Open3.capture2e("pg_restore", "--list", dump)
    expect(status).to be_success
    expect(listing).to include("TABLE DATA public purchases")

    expect(files["#{folder}/LEEME.txt"].force_encoding("UTF-8")).to include("base.dump: la base de datos completa", "pg_restore")
    expect(backup.dump_error).to be_nil
  ensure
    FileUtils.rm_rf(File.dirname(path)) if path
  end

  it "still gives the CSVs, and says why, when the server cannot make the dump" do
    allow(described_class).to receive(:tools).and_return(described_class::Tools.new(pg_dump_version: "15.4", server_version: "18.6"))
    backup = described_class.new(now:)
    path = backup.write
    files = entries(path)

    expect(files.keys.grep(/base\.dump/)).to be_empty
    expect(files.keys.grep(%r{/csv/})).not_to be_empty
    expect(files.keys.grep(/LEEME/).map { |key| files[key].force_encoding("UTF-8") }.sole).to include("pg_dump 15.4 es más viejo que la base de datos (PostgreSQL 18.6)")
  ensure
    FileUtils.rm_rf(File.dirname(path)) if path
  end
end
