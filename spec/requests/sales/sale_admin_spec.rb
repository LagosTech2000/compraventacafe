require "rails_helper"

# A sale is closed for everyone, administrators too (Fernando, 2026-11-18:
# «que no se pueda editar ... ni ventas»): no edits, a collection is not
# edited and only the latest one is removed; it is voided only without
# collections. Before (2026-11-12) an administrator edited it and voided it
# collected.
RSpec.describe "Sales, closed for administrators too" do
  let(:admin) { create(:user, :admin) }
  let(:buyer) { create(:buyer) }
  let(:account) { create(:money_account, opening_balance: 0) }
  let(:shipments) { create_list(:shipment, 2, :received, buyer:) }

  def page = Nokogiri::HTML(response.body)

  def sell(payment_status: "paid", **options)
    SaleIssuer.new(buyer:, user: admin, shipment_ids: shipments.map(&:id), sale: { price_unit: "pound", unit_price: "50", quintal_pounds: "120" },
                   payment_status:, payment_method: "cash", money_account_id: account.id, **options).call.sale
  end

  it "has no edit, for an administrator either" do
    sale = sell
    sign_in admin
    get sales_sale_path(sale)
    expect(page.css("a").map(&:text)).not_to include("Editar venta", "Editar")
    expect(Sale.method_defined?(:revise!)).to be(false)
  end

  it "voids a collected sale only after its collections are removed, the latest first" do
    advance = create(:buyer_advance, buyer:, amount: 1_000)
    sale = sell(payment_status: "pending")
    BuyerAdvanceSale.create!(buyer_advance: advance, sale:, percent: 50, applied_on: Time.zone.today, created_by: admin)
    cash = sale.payments.create!(amount: 100, paid_on: Time.zone.today, payment_method: "cash", money_account: account, created_by: admin)
    sign_in admin

    get sales_sale_path(sale)
    expect(page.at_css("form[action='#{void_sales_sale_path(sale)}']")).to be_nil
    patch void_sales_sale_path(sale), params: { sale: { void_reason: "Precio equivocado" } }
    expect(sale.reload).not_to be_voided

    advance_payment = sale.payments.advance.sole
    delete sales_sale_payment_path(sale, advance_payment)
    expect(advance_payment.reload).to be_present

    delete sales_sale_payment_path(sale, cash)
    delete sales_sale_payment_path(sale, advance_payment)
    expect(sale.payments.reload).to be_empty
    expect(buyer.reload.advance_balance).to eq(1_000)

    patch void_sales_sale_path(sale), params: { sale: { void_reason: "Precio equivocado" } }
    expect(sale.reload).to be_voided
    expect(shipments.map { it.reload.sale }).to all(be_nil)
  end

  it "never edits a collection, and the model refuses a change of its amount, date or method" do
    sale = sell(payment_status: "pending")
    first = sale.payments.create!(amount: 100, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)
    sale.payments.create!(amount: 200, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)
    sign_in admin

    get sales_sale_path(sale)
    expect(page.css("a").map(&:text)).not_to include("Editar")
    expect(first.update(amount: 150)).to be(false)
    expect(first.errors.full_messages.join).to include("Un cobro no se edita")
    expect(first.reload.update(money_account: account)).to be(true)

    delete sales_sale_payment_path(sale, first)
    expect(sale.payments.reload.map(&:amount)).to eq([ 100, 200 ])
  end
end
