# Fictitious data to show the system. Never real producers: the client's
# Excel holds real names, RTN and phones, which must not reach the repo.
namespace :demo do
  desc "Load fictitious zones, producers, purchases and invoices (not in production)"
  task seed: :environment do
    abort "demo:seed does not run in production." if Rails.env.production?

    user = User.active_admins.first or abort "Create an admin first with bin/rails db:seed."
    DemoData.new(user).load
    puts "Demo data loaded: #{Zone.count} zones, #{Producer.count} producers, #{Purchase.count} purchases, #{Invoice.count} invoices."
  end
end
