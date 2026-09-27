require "rails_helper"

RSpec.describe Purchase do
  it "stores the calculation on save" do
    purchase = create(:purchase, gross_weight: 146, humidity_percent: 51, price_per_pound: 58)
    expect(purchase.reload).to have_attributes(sacks: BigDecimal("0.8848"), tare: 1, net_weight: BigDecimal("71.05"), total: BigDecimal("4120.90"))
  end

  it "recalculates when the inputs change" do
    purchase = create(:purchase)
    purchase.update!(price_per_pound: 60)
    expect(purchase.total).to eq(BigDecimal("4263.00"))
  end

  it "validates the inputs in Spanish" do
    purchase = build(:purchase, gross_weight: 0, humidity_percent: 100, price_per_pound: -1, coffee_state: "oro")
    expect(purchase).not_to be_valid
    expect(purchase.errors.full_messages).to include(
      "Peso bruto (lb) debe ser mayor que 0", "Humedad (%) debe ser menor que 100",
      "Precio por libra (L) debe ser mayor que 0", "Estado del café no está incluido en la lista"
    )
  end

  it "accepts the three coffee states the client buys" do
    %w[cherry wet_parchment dry_parchment].each { |state| expect(build(:purchase, coffee_state: state)).to be_valid }
  end

  it "labels coffee states in Spanish" do
    expect(build(:purchase, coffee_state: "cherry").human_coffee_state).to eq("Uva")
  end
end
