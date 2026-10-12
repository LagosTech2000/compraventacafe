require "rails_helper"

RSpec.describe Purchase do
  it "stores the calculation on save" do
    purchase = create(:purchase, gross_weight: 146, humidity_percent: 51, price_per_pound: 58)
    expect(purchase.reload).to have_attributes(sacks: BigDecimal("0.8848"), tare: 1, net_weight: BigDecimal("71.05"), total: BigDecimal("4120.90"))
  end

  it "stores what damage takes off, in pounds and lempiras, only in parchment" do
    purchase = create(:purchase, gross_weight: 146, humidity_percent: 51, damage_percent: 2.5, price_per_pound: 58)
    expect(purchase.reload).to have_attributes(damage_weight: BigDecimal("1.78"), damage_amount: BigDecimal("103.24"))
    purchase.update!(coffee_state: "cherry", yield_factor: 0.186)
    expect(purchase.reload).to have_attributes(damage_weight: nil, damage_amount: nil)
  end

  it "takes an empty damage as 0 % in parchment" do
    purchase = create(:purchase, gross_weight: 146, humidity_percent: 51, damage_percent: nil, price_per_pound: 58)
    expect(purchase.reload).to have_attributes(damage_percent: 0, damage_weight: 0, net_weight: BigDecimal("71.05"))
  end

  describe "by weighings" do
    def weighings(*pairs) = pairs.map { |gross, sacks| { gross_weight: gross, sacks: } }

    it "sums the weighings into the gross weight and the sacks, with 1 lb of tare per counted sack" do
      purchase = create(:purchase, weight_mode: "weighings", gross_weight: 1, humidity_percent: 51,
                                   weighings_attributes: weighings([ 300, 2 ], [ 300, 2 ], [ 300, 2 ]))
      expect(purchase.reload).to have_attributes(gross_weight: 900, sacks: 6, tare: 6, net_weight: BigDecimal("438.06"))
      expect(purchase.weighings.size).to eq(3)
    end

    it "recalculates when a weighing changes, is added or removed" do
      purchase = create(:purchase, weight_mode: "weighings", weighings_attributes: weighings([ 300, 2 ], [ 300, 2 ]))
      first, second = purchase.weighings.to_a

      purchase.update!(weighings_attributes: [ { id: first.id, sacks: 3 } ])
      expect(purchase.reload).to have_attributes(gross_weight: 600, sacks: 5, tare: 5)

      purchase.update!(weighings_attributes: [ { id: second.id, _destroy: "1" }, { gross_weight: 150, sacks: 1 } ])
      expect(purchase.reload).to have_attributes(gross_weight: 450, sacks: 4, tare: 4)
    end

    it "requires at least one weighing, each with weight and sacks, in Spanish" do
      purchase = build(:purchase, weight_mode: "weighings")
      expect(purchase.tap(&:valid?).errors.full_messages).to include("Pesadas faltan: agrega al menos una pesada")

      purchase = build(:purchase, weight_mode: "weighings", weighings_attributes: weighings([ 0, 1.5 ]))
      expect(purchase.tap(&:valid?).errors.full_messages).to include(
        "Peso de la pesada (lb) debe ser mayor que 0", "Sacos de la pesada debe ser un entero"
      )
    end

    it "drops the weighings and goes back to the usual tare when switched to one figure" do
      purchase = create(:purchase, weight_mode: "weighings", weighings_attributes: weighings([ 300, 2 ]))
      purchase.update!(weight_mode: "single", gross_weight: 146)
      expect(purchase.reload).to have_attributes(sacks: BigDecimal("0.8848"), tare: 1, net_weight: BigDecimal("71.05"))
      expect(PurchaseWeighing.count).to eq(0)
    end
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

  it "uses humidity and damage in parchment, and the yield in cherry" do
    parchment = create(:purchase, coffee_state: "dry_parchment", humidity_percent: 12, damage_percent: 2, yield_factor: 0.5)
    expect(parchment).to have_attributes(yield_factor: nil, net_weight: BigDecimal("125.05"))

    cherry = create(:purchase, coffee_state: "cherry", gross_weight: 1000, humidity_percent: 51, damage_percent: 2, yield_factor: 0.186)
    expect(cherry).to have_attributes(humidity_percent: nil, damage_percent: nil, net_weight: BigDecimal("184.70"))
  end

  it "requires the inputs of its coffee state, in Spanish" do
    expect(build(:purchase, coffee_state: "cherry", yield_factor: nil).tap(&:valid?).errors.full_messages).to include("Rendimiento no es un número")
    expect(build(:purchase, humidity_percent: nil).tap(&:valid?).errors.full_messages).to include("Humedad (%) no es un número")
    expect(build(:purchase, damage_percent: -1).tap(&:valid?).errors.full_messages).to include("Daño (%) debe ser mayor o igual que 0")
    expect(build(:purchase, coffee_state: "cherry", yield_factor: 1.5)).not_to be_valid
  end

  it "keeps its stored results when saved without changing the inputs" do
    purchase = create(:purchase)
    purchase.update_columns(net_weight: 1, total: 1)
    purchase.update!(observations: "Revisada")
    expect(purchase.reload).to have_attributes(net_weight: 1, total: 1)
  end

  it "belongs to the season of its date" do
    expect(create(:purchase, purchased_at: Date.new(2026, 8, 31)).season_year).to eq(2025)
    expect(create(:purchase, purchased_at: Date.new(2026, 9, 1)).season).to eq(Season.new(2026))
  end

  it "shows its net weight in quintals" do
    expect(build(:purchase, net_weight: 250).quintals).to eq(2)
  end

  it "is voided by a user and leaves every list of pending work" do
    user = create(:user)
    purchase = create(:purchase)
    purchase.void!(user)
    expect(purchase.reload).to have_attributes(voided?: true, voided_by: user)
    expect(Purchase.uninvoiced).not_to include(purchase)
    expect(Purchase.active).not_to include(purchase)
  end

  it "cannot be voided once invoiced" do
    purchase = create(:invoice).purchases.first
    expect { purchase.void!(create(:user)) }.to raise_error(ActiveRecord::RecordInvalid, /facturada no se puede anular/)
  end

  it "labels coffee states in Spanish" do
    expect(build(:purchase, coffee_state: "cherry").human_coffee_state).to eq("Uva")
  end
end
