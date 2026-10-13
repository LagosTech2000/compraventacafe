require "csv"
require "open3"

# A full copy of the data for the administrator to keep: a .zip holding one
# folder with
#
#   base.dump    the whole database (pg_dump, custom format), to restore
#                with pg_restore. pg_dump cannot copy a server newer than
#                itself: when it is missing or older, the dump is left out
#                and LEEME.txt says why; the CSVs are always there.
#   csv/*.csv    one per table, readable in Excel (with BOM), without
#                secrets (password digests) and without sign-in sessions.
#   LEEME.txt    what is inside and how to restore it.
#
#   path = DataBackup.new.write   # a temporary .zip; the caller removes it
class DataBackup
  # Never in the CSVs: password digests (the dump keeps them, it restores
  # the whole system), sign-in sessions and Rails' own bookkeeping.
  SKIPPED_TABLES = %w[schema_migrations ar_internal_metadata sessions].freeze
  SECRET_COLUMNS = Auditable::SENSITIVE_ATTRIBUTES

  Tools = Data.define(:pg_dump_version, :server_version) do
    def pg_dump_found? = pg_dump_version.present?
    # pg_dump copies servers up to its own major version.
    def dump_possible? = pg_dump_found? && pg_dump_version.to_i >= server_version.to_i
  end

  def self.tools
    output, status = Open3.capture2e("pg_dump", "--version")
    version = output[/\d+(\.\d+)*/] if status.success?
    server = ActiveRecord::Base.connection.select_value("SHOW server_version")[/\d+(\.\d+)*/]
    Tools.new(pg_dump_version: version, server_version: server)
  rescue Errno::ENOENT
    Tools.new(pg_dump_version: nil, server_version: ActiveRecord::Base.connection.select_value("SHOW server_version")[/\d+(\.\d+)*/])
  end

  attr_reader :dump_error

  def initialize(now: Time.current)
    @now = now
  end

  def folder_name = "respaldo-#{@now.strftime("%Y-%m-%d-%H%M")}"
  def file_name = "#{folder_name}.zip"

  def tables
    ActiveRecord::Base.connection.tables.sort - SKIPPED_TABLES
  end

  # Writes the .zip and returns its path (in a temporary folder).
  def write
    dir = Dir.mktmpdir("respaldo")
    dump = File.join(dir, "base.dump")
    dumped = dump_database(dump)

    zip_path = File.join(dir, file_name)
    Zip::File.open(zip_path, create: true) do |zip|
      zip.add("#{folder_name}/base.dump", dump) if dumped
      tables.each do |table|
        zip.get_output_stream("#{folder_name}/csv/#{table}.csv") { |io| io.write(csv_for(table)) }
      end
      zip.get_output_stream("#{folder_name}/LEEME.txt") { |io| io.write(readme(dumped)) }
    end
    zip_path
  end

  private
    def dump_database(path)
      tools = self.class.tools
      unless tools.dump_possible?
        @dump_error = tools.pg_dump_found? ? I18n.t("administration.backups.readme.old_pg_dump", pg_dump: tools.pg_dump_version, server: tools.server_version) :
                                             I18n.t("administration.backups.readme.no_pg_dump")
        return false
      end

      output, status = Open3.capture2e(pg_env, "pg_dump", "--format=custom", "--no-owner", "--no-acl",
                                       "--exclude-table-data=sessions", "--file=#{path}", *pg_target)
      return true if status.success?

      @dump_error = I18n.t("administration.backups.readme.dump_failed", error: output.lines.last.to_s.strip)
      false
    end

    # Where the database is, from the app's own connection settings (Rails
    # breaks DATABASE_URL into these too). Passed in the environment, so the
    # password is never on the command line.
    def pg_env
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      { "PGHOST" => config[:host], "PGPORT" => config[:port]&.to_s, "PGUSER" => config[:username],
        "PGPASSWORD" => config[:password], "PGSSLMODE" => config[:sslmode] }.compact
    end

    def pg_target
      [ ActiveRecord::Base.connection_db_config.configuration_hash[:database] ]
    end

    # The table as CSV, its columns as the database names them.
    def csv_for(table)
      connection = ActiveRecord::Base.connection
      columns = connection.columns(table).map(&:name) - SECRET_COLUMNS
      order = columns.include?("id") ? " ORDER BY id" : ""
      rows = connection.select_rows("SELECT #{columns.map { |column| connection.quote_column_name(column) }.join(", ")} " \
                                    "FROM #{connection.quote_table_name(table)}#{order}")
      "﻿" + CSV.generate { |csv| csv << columns; rows.each { |row| csv << row } }
    end

    def readme(dumped)
      I18n.t("administration.backups.readme.body",
             business: SiteSetting.current.business_name, at: I18n.l(@now, format: :audit),
             dump: dumped ? I18n.t("administration.backups.readme.dump_included") : dump_error,
             tables: tables.size)
    end
end
