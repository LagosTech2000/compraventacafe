module Administration
  # The data backup (DataBackup): what it holds, whether the database dump
  # can be made on this server, and the download. Each download is audited.
  class BackupsController < ApplicationController
    # A backup dumps the whole database: a few per hour are plenty.
    rate_limit_per_user name: "backup", to: 3, within: 1.hour, only: :create

    def show
      authorize :backup
      @tools = DataBackup.tools
      @tables = DataBackup.new.tables
    end

    def create
      authorize :backup
      backup = DataBackup.new
      path = backup.write
      AuditEvent.record!(action: "backup", label: backup.file_name,
                         changeset: { "dump" => [ nil, backup.dump_error.nil? ] })
      send_data File.binread(path), filename: backup.file_name, type: "application/zip", disposition: "attachment"
    ensure
      FileUtils.rm_rf(File.dirname(path)) if path
    end
  end
end
