require "rails_helper"

RSpec.describe Sale do
  let(:buyer) { create(:buyer) }
  let(:user) { create(:user) }

  it "charges the buyer's net by the quintal of 120 lb or by the pound" do
    expect(described_class.amount_for(BigDecimal("1245"), unit_price: 6_000, price_unit: "quintal")).to eq(BigDecimal("62250"))
    expect(described_class.amount_for(BigDecimal("100.5"), unit_price: 63, price_unit: "pound")).to eq(BigDecimal("6331.50"))
  end

  it "takes its own pounds per quintal, 120 unless it says otherwise" do
    expect(described_class.amount_for(BigDecimal("1245"), unit_price: 6_000, price_unit: "quintal", quintal_pounds: 100)).to eq(BigDecimal("74700"))

    shipment = create(:shipment, :received, buyer:)
    sale = SaleIssuer.new(buyer:, user:, shipment_ids: [ shipment.id ], sale: { price_unit: "quintal", unit_price: 6_000, quintal_pounds: "100" }).call.sale
    expect(sale).to have_attributes(quintal_pounds: 100, total: BigDecimal("28929.60"), quintals: BigDecimal("4.82"))
    expect(sale.human_price_unit).to eq("Por quintal de 100 lb")
    expect(create(:sale).quintal_pounds).to eq(120)

    expect(build(:sale, buyer:).tap { it.quintal_pounds = 0 }.tap(&:valid?).errors[:quintal_pounds]).to be_present
  end

  it "says what a sum of money is in coffee at its price: net and gross pounds" do
    sale = create(:sale) # 482.16 lb net (990 gross) at L 6,000 the QQ of 120 lb: L 50 a pound
    expect(sale.price_per_pound).to eq(50)
    expect(sale.pounds_for(3_000)).to eq(net: BigDecimal("60"), gross: BigDecimal("123.20"))

    by_pound = create(:sale, price_unit: "pound", unit_price: 60)
    expect(by_pound.pounds_for(600)[:net]).to eq(10)
  end

  it "keeps the weights of its shipments and numbers the sales in order" do
    shipments = create_list(:shipment, 2, :received, buyer:)
    sale = SaleIssuer.new(buyer:, user:, shipment_ids: shipments.map(&:id), sale: { price_unit: "pound", unit_price: 60 }).call.sale
    expect(sale).to have_attributes(number: 1, net_weight: BigDecimal("964.32"), origin_net_weight: BigDecimal("974.12"),
                                    total: BigDecimal("57859.20"), payment_status: "pending")
    expect(sale.quintals).to eq(BigDecimal("8.04"))
    expect(sale.lines.map(&:amount)).to all(eq(BigDecimal("28929.60")))
  end

  it "is paid on the spot (contado) or in part, all or nothing" do
    shipment = create(:shipment, :received, buyer:)
    paid = SaleIssuer.new(buyer:, user:, shipment_ids: [ shipment.id ], payment_status: "paid", payment_method: "cash",
                          sale: { price_unit: "pound", unit_price: 60 }).call.sale
    expect(paid).to be_paid
    expect(paid.payments.sum(:amount)).to eq(paid.total)

    other = create(:shipment, :received, buyer:)
    result = SaleIssuer.new(buyer:, user:, shipment_ids: [ other.id ], payment_status: "partial", payment_method: "cash", amount: 99_999_999,
                            sale: { price_unit: "pound", unit_price: 60 }).call
    expect(result).not_to be_success
    expect(other.reload.status).to eq("received")
  end

  it "goes pending → partial → paid with its payments, never over what is owed" do
    sale = create(:sale, buyer:)
    create(:sale_payment, sale:, amount: 100)
    expect(sale.reload).to be_partial
    over = SalePayment.new(sale:, amount: sale.balance_due + 1, paid_on: Time.zone.today, payment_method: "cash", created_by: user)
    expect(over).not_to be_valid
    create(:sale_payment, sale:, amount: sale.balance_due)
    expect(sale.reload).to be_paid
  end
end
