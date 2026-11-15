require "rails_helper"

# «Café corriente» (Fernando, 2026-11-12): only for wet parchment. It will
# not count in the end-of-season retention, an open point not built yet.
RSpec.describe Purchase, "café corriente" do
  it "is kept on wet parchment and shown with its state" do
    purchase = create(:purchase, coffee_state: "wet_parchment", common_coffee: true)
    expect(purchase.reload).to be_common_coffee
    expect(purchase.coffee_label).to eq("Pergamino húmedo · Café corriente")
  end

  it "never stays on another state" do
    expect(create(:purchase, coffee_state: "dry_parchment", common_coffee: true)).not_to be_common_coffee
    purchase = create(:purchase, coffee_state: "wet_parchment", common_coffee: true)
    purchase.update!(coffee_state: "cherry", yield_factor: 0.186)
    expect(purchase.reload).not_to be_common_coffee
  end
end

RSpec.describe "Nueva compra with «Café corriente»", type: :request do
  it "saves the mark from the form" do
    sign_in create(:user, :admin)
    producer = create(:producer)
    post trading_purchases_path, params: { purchase: { producer_id: producer.id, purchased_at: Time.zone.now, coffee_state: "wet_parchment",
                                                       common_coffee: "1", gross_weight: "146", humidity_percent: "51",
                                                       damage_percent: "0", price_per_pound: "58" } }
    expect(Purchase.last).to be_common_coffee
    get trading_purchase_path(Purchase.last)
    expect(response.body).to include("Pergamino húmedo · Café corriente")
  end
end
