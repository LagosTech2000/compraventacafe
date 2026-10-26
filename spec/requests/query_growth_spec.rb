require "rails_helper"

# The app always fast (Fernando, 2026-10-18): a list or the home page makes
# the same number of queries with 2 rows as with 6, never one more per row.
# Bullet catches associations loaded per row; this catches the rest.
RSpec.describe "Queries per page" do
  include ActiveSupport::Testing::TimeHelpers

  let(:admin) { create(:user, :admin) }

  PAGES = %w[/ /pending_work /trading /trading/purchases /trading/producers /trading/invoices /trading/daily_close
             /trading/haulers /sales /sales/shipments /sales/sales /sales/buyers /sales/carriers /sales/trucks /sales/stock /sales/conversions /sales/daily_close /finance /finance/movements /finance/incomes /finance/staff /finance/staff/roles /finance/staff/sheet /finance/staff/sheet?view=month /finance/staff/sheet?view=history /finance/expenses /finance/money_accounts /finance/categories /finance/budget /loans /loans/loans /loans/credit_accounts /farms/farms /administration/people].freeze

  def queries(path)
    count = 0
    # The session's activity (at most once a minute) and the pages visited
    # depend on the clock, not on the rows.
    counter = lambda do |*, payload|
      next if payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached] || payload[:sql].match?(/"(sessions|page_visits)"/)

      count += 1
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    expect(response).to have_http_status(:ok)
    count
  end

  def add_records(count)
    zone = create(:zone)
    count.times do |index|
      producer = create(:producer, person: create(:person, zone:))
      producer.farms.create!(name: "Finca #{index}")
      create(:purchase, producer:, zone:)
      create(:loan_payment, loan: create(:loan, person: producer.person), amount: 100)
      create(:hauler)
      create(:sale, buyer: create(:buyer))
      create(:shipment, carrier: create(:carrier), truck: create(:truck))
      create(:coffee_conversion, :finished)
      create(:coffee_conversion)
      create(:expense)
      create(:other_income)
      member = create(:staff_member, starts_on: Time.zone.today - 40)
      create(:staff_advance, member:, given_on: member.period_to_pay.starts_on)
      create(:staff_goal, member:)
      member.attendances.create!(worked_on: Time.zone.today.beginning_of_month, day_fraction: 1)
    end
  end

  # The clock stands still while measuring (the session's activity moves
  # with it); travel_back puts it back for the next specs.
  around { |example| freeze_time { example.run } }

  it "does not ask once more per row" do
    sign_in admin
    add_records(2)
    few = PAGES.index_with { |path| queries(path) }

    add_records(4)
    # Four rows more: a query per row would add 4 or more. A preload that
    # runs only when its list is not empty may add one or two.
    grown = PAGES.index_with { |path| queries(path) }.select { |path, count| count > few[path] + 2 }

    expect(grown).to be_empty, "pages with more queries with more rows: #{grown.map { |path, count| "#{path} #{few[path]} → #{count}" }.join(", ")}"
  end
end
