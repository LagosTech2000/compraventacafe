require "rails_helper"

# Nothing is dated in the future (Fernando, 2026-11-18): the forms stop at
# today before sending, as the server does.
RSpec.describe "Date limits in the forms" do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "stops the date and time fields at today" do
    today = Time.zone.today.iso8601

    get new_trading_purchase_path
    expect(response.body).to include(%(max="#{today}T23:59:00"))

    get new_sales_shipment_path
    expect(response.body).to include(%(max="#{today}T23:59:00"))

    get new_finance_expense_path
    expect(response.body).to match(/name="expense\[spent_on\]"[^>]*max="#{today}"|max="#{today}"[^>]*name="expense\[spent_on\]"/)
  end

  it "refuses a purchase dated tomorrow, in Spanish" do
    producer = create(:producer)
    post trading_purchases_path, params: { purchase: attributes_for(:purchase).merge(producer_id: producer.id, purchased_at: 1.day.from_now, hauler_choice: "none") }
    expect(response.body).to include("no puede ser una fecha futura")
    expect(Purchase.count).to eq(0)
  end
end
