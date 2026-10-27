require "rails_helper"

# «Nueva compra» warns, without stopping it, about values that look like a
# typo (unusual_values_controller.js, Fernando 2026-10-25): humidity or
# yield far from the usual one, a price far from the day's average.
RSpec.describe "Purchase form unusual values", type: :system do
  let(:user) { create(:user, :admin) }

  before do
    create(:purchase, price_per_pound: 60) # today's wet parchment average: L 60
    sign_in_as(user)
    visit new_trading_purchase_path
  end

  def warning(name) = find("[data-unusual-values-target='#{name}Warning']", visible: :all)

  it "warns about humidity, yield and price far from the usual, and goes away when fixed" do
    fill_in "purchase_humidity_percent", with: "15"
    expect(warning("humidity")).to have_text("15 % es muy poca humedad para Pergamino húmedo; lo normal está cerca de 51 %")
    fill_in "purchase_humidity_percent", with: "52"
    expect(warning("humidity")).not_to be_visible

    fill_in "purchase_price_per_pound", with: "6"
    expect(warning("price")).to have_text("Este precio está 90 % abajo del promedio de hoy para Pergamino húmedo (L 60.00)")
    fill_in "purchase_price_per_pound", with: "61"
    expect(warning("price")).not_to be_visible

    select "Uva", from: "purchase_coffee_state"
    fill_in "purchase_yield_factor", with: "0.5"
    expect(warning("yield")).to have_text("Un rendimiento de 0.5 es muy alto; lo normal está cerca de 0.186")
    fill_in "purchase_price_per_pound", with: "6" # no cherry bought today: nothing to compare
    expect(warning("price")).not_to be_visible
  end
end
