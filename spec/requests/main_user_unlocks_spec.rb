require "rails_helper"

# The main user (User::DATA_EXPORTER_ID) edits what is closed to everybody
# else, administrators included (Fernando, 2026-11-22: «el único que pueda
# editar todo sin importar lo que sea es el usuario id 1»).
RSpec.describe "The main user edits what is closed" do
  let(:admin) { create(:user, :admin) }
  let(:main) { make_data_exporter(create(:user, :admin)) }
  let(:producer) { create(:producer) }

  def as(user)
    sign_in user
    Current.session = user.sessions.last
    yield
  ensure
    Current.reset
  end

  def invoiced_purchase
    purchase = create(:purchase, producer:, gross_weight: 1_000)
    InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call
    purchase.reload
  end

  it "edits an invoiced purchase; another administrator cannot" do
    purchase = invoiced_purchase
    as(admin) do
      expect(PurchasePolicy.new(admin, purchase).update?).to be(false)
      expect(purchase.update(gross_weight: 900)).to be(false)
    end
    as(main) do
      expect(PurchasePolicy.new(main, purchase).update?).to be(true)
      expect(purchase.reload.update(gross_weight: 900)).to be(true)
    end
  end

  it "registers on a closed day and edits a weighed shipment" do
    shipment = create(:shipment, departed_at: 2.days.ago)
    shipment.update_columns(received_on: Time.zone.today, destination_gross_weight: 500, destination_sacks: 3, destination_humidity_percent: 51, destination_damage_percent: 0, destination_net_weight: 240)
    BusinessDayClose.create!(closed_on: Time.zone.yesterday, closed_by: admin)
    as(admin) do
      expect(build(:purchase, purchased_at: 2.days.ago)).not_to be_valid
      expect(ShipmentPolicy.new(admin, shipment).update?).to be(false)
    end
    as(main) do
      expect(build(:purchase, purchased_at: 2.days.ago)).to be_valid
      expect(ShipmentPolicy.new(main, shipment).update?).to be(true)
      shipment.reload.update(origin_sacks: 7)
      expect(shipment.errors.full_messages).to eq([])
    end
  end

  it "edits a loan with payments" do
    loan = create(:loan)
    create(:loan_payment, loan:, amount: 10, paid_on: Time.zone.today, payment_method: "cash")
    expect(LoanPolicy.new(admin, loan).update?).to be(false)
    expect(LoanPolicy.new(main, loan).update?).to be(true)
  end

  # The buyer's scale of a sold shipment, its sale recalculated (Fernando, 2026-11-23).
  it "weighs a sold shipment again on the buyer's scale and recalculates its sale" do
    sale = create(:sale)
    shipment = sale.shipments.first
    expect(ShipmentPolicy.new(admin, shipment).receive?).to be(false)

    sign_in main
    patch sales_shipment_arrival_path(shipment), params: { shipment: { destination_gross_weight: "2000" } }
    expect(shipment.reload.destination_gross_weight).to eq(2_000)
    expect(sale.reload.net_weight).to eq(shipment.destination_net_weight)
  end
end
