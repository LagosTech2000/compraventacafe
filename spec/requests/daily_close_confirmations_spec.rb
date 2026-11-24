require "rails_helper"

# The daily closes (Fernando, 2026-11-23): arrows to the day before and
# after, «Confirmar cierre» (reviewed, no lock) and the day's fuel close,
# one per day for the whole business, shown in Compra de café and in
# Comercialización.
RSpec.describe "Daily closes: day arrows, confirmation and fuel" do
  let(:admin) { create(:user, :admin) }
  let(:day) { Time.zone.yesterday }

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "moves to the day before and after, never past today" do
    get trading_daily_close_path(date: day)
    expect(page.at_css("[data-day-picker='previous']")["href"]).to eq(trading_daily_close_path(date: day - 1))
    expect(page.at_css("[data-day-picker='next']")["href"]).to eq(trading_daily_close_path(date: day + 1))
    get sales_daily_close_path
    expect(page.at_css("[data-day-picker='next']")).to be_nil
    get loans_daily_close_path(date: day)
    expect(page.at_css("[data-day-picker='previous']")).to be_present
  end

  it "confirms a module's close once, with who and when, and an administrator takes it back" do
    post daily_close_confirmations_path(module_key: "trading", day:)
    confirmation = DailyCloseConfirmation.sole
    expect(confirmation).to have_attributes(module_key: "trading", day:, confirmed_by: admin)
    post daily_close_confirmations_path(module_key: "trading", day:)
    expect(DailyCloseConfirmation.count).to eq(1)

    get trading_daily_close_path(date: day)
    expect(page.at_css("[data-daily-close-confirmation='confirmed']").text).to include("Confirmado por #{admin.name}")
    get sales_daily_close_path(date: day)
    expect(page.at_css("[data-daily-close-confirmation='open']")).to be_present

    delete daily_close_confirmation_path(confirmation)
    expect(DailyCloseConfirmation.count).to eq(0)
  end

  it "lists the day's fuel and closes it once for the whole business" do
    gas = create(:supply, name: "Diésel", unit: "litro", business_use: true)
    create(:supply_entry, supply: gas, quantity: 100, amount: 10_000, received_on: day - 1)
    vehicle = create(:vehicle, plate: "HAA 1234")
    create(:supply_exit, kind: "business_use", exited_on: day, vehicle:, supply: gas, quantity: 30, person: nil, money_account: nil, payment_method: nil)

    get sales_daily_close_path(date: day)
    table = page.at_css("[data-fuel-day-table]").text
    expect(table).to include("HAA 1234", "Diésel", "30 litro")

    post fuel_day_closes_path(day:)
    expect(FuelDayClose.sole).to have_attributes(day:, closed_by: admin)
    post fuel_day_closes_path(day:)
    expect(FuelDayClose.count).to eq(1)
    expect(flash[:alert]).to include("no se hace dos veces")

    get trading_daily_close_path(date: day)
    expect(page.at_css("[data-fuel-day='closed']").text).to include("Combustible cerrado por #{admin.name}")
  end

  it "lets who sees only a daily close confirm it but not take it back", :all_records do
    clerk = create(:user).tap { create(:permission, user: it, module_key: "trading", submodule_key: "daily_close", can_read: true) }
    sign_in clerk
    post daily_close_confirmations_path(module_key: "trading", day:)
    expect(DailyCloseConfirmation.count).to eq(1)
    post daily_close_confirmations_path(module_key: "sales", day:)
    expect(DailyCloseConfirmation.count).to eq(1)
    delete daily_close_confirmation_path(DailyCloseConfirmation.sole)
    expect(DailyCloseConfirmation.count).to eq(1)
    post fuel_day_closes_path(day:)
    expect(FuelDayClose.count).to eq(1)
  end
end
