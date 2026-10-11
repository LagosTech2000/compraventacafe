# Fictitious data to show the system. Never real producers: the client's
# Excel holds real names, RTN and phones, which must not reach the repo.
namespace :demo do
  desc "Load fictitious zones, producers, purchases, invoices and loans (not in production)"
  task seed: :environment do
    abort "demo:seed does not run in production." if Rails.env.production?

    user = User.active_admins.first or abort "Create an admin first with bin/rails db:seed."
    DemoData.new(user).load
    puts "Demo data loaded: #{Zone.count} zones, #{Producer.count} producers, #{Purchase.count} purchases, #{Invoice.count} invoices, #{Loan.count} loans."
  end

  desc "Load a year of fictitious operation for the reports (not in production)"
  task reports: :environment do
    abort "demo:reports does not run in production." if Rails.env.production?
    abort "demo:reports is already loaded (#{ReportDemoData::MARKER_FARM} exists)." if ReportDemoData.loaded?

    user = User.active_admins.first or abort "Create an admin first with bin/rails db:seed."
    started = Time.current
    data = ReportDemoData.new(user).load
    puts "Report demo data loaded in #{(Time.current - started).round} s: " +
         data.counts.map { |name, count| "#{count} #{name}" }.join(", ") + "."
  end
end
