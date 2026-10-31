# Undoes a Consolidación done by mistake (ConsolidationRevert), from the
# Render shell:
#
#   bin/rails consolidation:list                      # consolidations, newest first
#   bin/rails "consolidation:revert[REQUEST_ID]"      # shows what would change
#   CONFIRM=1 bin/rails "consolidation:revert[REQUEST_ID]"   # does it
#
# Several ids go separated by spaces; "all" undoes every consolidation.
namespace :consolidation do
  desc "Lists the consolidations (Control financiero → Consolidación) found in the audit"
  task list: :environment do
    groups = ConsolidationRevert.groups
    puts "No consolidations found." if groups.empty?
    groups.each do |group|
      accounts = group.events.filter_map { |event| event.changeset.dig("money_account_id", 1) }.tally
      categories = group.events.filter_map { |event| event.changeset.dig("expense_category_id", 1) }.tally
      puts "#{group.request_id}  #{group.at.in_time_zone.strftime('%d/%m/%Y %H:%M')}  #{group.user || '-'}  #{group.events.size} records"
      accounts.each { |id, count| puts "    account: #{MoneyAccount.find_by(id:)&.name || id} (#{count})" }
      categories.each { |id, count| puts "    category: #{ExpenseCategory.find_by(id:)&.name || id} (#{count})" }
    end
  end

  desc "Undoes consolidations by request id (or all); CONFIRM=1 applies"
  task :revert, [ :request_ids ] => :environment do |_task, args|
    abort "Usage: bin/rails \"consolidation:revert[REQUEST_ID]\" (see consolidation:list)" if args[:request_ids].blank?

    ids = args[:request_ids].strip == "all" ? :all : args[:request_ids].split
    revert = ConsolidationRevert.new(ids)
    abort "No consolidation with that id." if revert.groups.empty?

    revert.changes.each do |change|
      puts "#{change.event.auditable_label}: #{change.restore.map { |column, value| "#{column} -> #{value.inspect}" }.join(', ')}"
    end
    skipped = revert.groups.sum { |group| group.events.size } - revert.changes.size
    puts "#{revert.changes.size} records to revert; #{skipped} already changed since (left as they are)."

    if ENV["CONFIRM"] == "1"
      puts "Reverted #{revert.apply!} records."
    else
      puts "Nothing changed. Run again with CONFIRM=1 to apply."
    end
  end
end
