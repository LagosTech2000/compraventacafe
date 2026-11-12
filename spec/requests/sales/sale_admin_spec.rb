require "rails_helper"

# Administrators edit and void sales, even collected (Fernando,
# 2026-11-12): date, price, quintal, document, observations and shipments;
# voided with payments, these are removed; a total below what was collected
# is saved and shows as overpaid.
RSpec.describe "Sales, administrators" do
  let(:admin) { create(:user, :admin) }
  let(:clerk) { create(:user).tap { create(:permission, user: it, module_key: "sales", can_read: true, can_create: true, can_update: true, can_destroy: true) } }
  let(:buyer) { create(:buyer) }
  let(:account) { create(:money_account, opening_balance: 0) }
  let(:shipments) { create_list(:shipment, 2, :received, buyer:) }

  def page = Nokogiri::HTML(response.body)

  def sell(payment_status: "paid", **options)
    SaleIssuer.new(buyer:, user: admin, shipment_ids: shipments.map(&:id), sale: { price_unit: "pound", unit_price: "50", quintal_pounds: "120" },
                   payment_status:, payment_method: "cash", money_account_id: account.id, **options).call.sale
  end

  it "edits the price, document and shipments of a collected sale, and a lower total shows as overpaid" do
    sale = sell
    collected = sale.paid_total
    extra = create(:shipment, :received, buyer:)
    sign_in admin
    get edit_sales_sale_path(sale)
    expect(response).to have_http_status(:ok)

    patch sales_sale_path(sale), params: { sale: { sold_on: sale.sold_on, price_unit: "pound", unit_price: "40", quintal_pounds: "120",
                                                   buyer_document_number: "F-123", shipment_ids: [ shipments.first.id, extra.id ] } }
    expect(response).to redirect_to(sales_sale_path(sale))
    sale.reload
    expect(sale.shipments).to contain_exactly(shipments.first, extra)
    expect(shipments.last.reload.sale).to be_nil
    expect(sale.net_weight).to eq(shipments.first.destination_net_weight + extra.destination_net_weight)
    expect(sale.total).to eq((sale.net_weight * 40).round(2))
    expect(sale.lines.map(&:amount).sum).to be_within(0.05).of(sale.total)
    expect(sale.buyer_document_number).to eq("F-123")
    expect(sale).to be_paid
    expect(sale.overpaid_amount).to eq(collected - sale.total)
    get sales_sale_path(sale)
    expect(page.at_css("[data-sale-overpaid]")).to be_present

    patch sales_sale_path(sale), params: { sale: { sold_on: sale.sold_on, price_unit: "pound", unit_price: "40", quintal_pounds: "120",
                                                   shipment_ids: [ create(:shipment, :received).id ] } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "voids a collected sale: its payments go, advances come back and its shipments are free" do
    create(:buyer_advance, buyer:, amount: 1_000)
    sale = sell(payment_status: "pending", advance_amount: "500")
    sale.payments.create!(amount: 100, paid_on: Time.zone.today, payment_method: "cash", money_account: account, created_by: admin)
    expect(buyer.reload.advance_balance).to eq(500)

    sign_in clerk
    patch void_sales_sale_path(sale), params: { sale: { void_reason: "x" } }
    expect(sale.reload).not_to be_voided

    sign_in admin
    get sales_sale_path(sale)
    expect(page.at_css("[data-void-with-payments]")).to be_present
    patch void_sales_sale_path(sale), params: { sale: { void_reason: "Precio equivocado" } }
    sale.reload
    expect(sale).to be_voided
    expect(sale.payments).to be_empty
    expect(buyer.reload.advance_balance).to eq(1_000)
    expect(AccountBalance.new.for(account)).to eq(0)
    expect(shipments.map { it.reload.sale }).to all(be_nil)
  end

  it "edits or removes any payment" do
    sale = sell(payment_status: "pending")
    first = sale.payments.create!(amount: 100, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)
    sale.payments.create!(amount: 200, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)
    sign_in admin

    patch sales_sale_payment_path(sale, first), params: { sale_payment: { amount: "150", paid_on: Time.zone.today, payment_method: "transfer" } }
    expect(first.reload).to have_attributes(amount: 150, payment_method: "transfer")
    expect(sale.reload.paid_total).to eq(350)

    patch sales_sale_payment_path(sale, first), params: { sale_payment: { amount: sale.total.to_s, paid_on: Time.zone.today, payment_method: "cash" } }
    expect(response).to have_http_status(:unprocessable_content)

    delete sales_sale_payment_path(sale, first)
    expect(sale.payments.reload.map(&:amount)).to eq([ 200 ])
  end

  it "is for administrators only, even with every permission of Comercialización" do
    sale = sell
    sign_in clerk
    get edit_sales_sale_path(sale)
    expect(response).to redirect_to(root_path)
    get sales_sale_path(sale)
    expect(page.css("a").map(&:text)).not_to include("Editar venta")
    expect(page.css("a").map(&:text)).not_to include("Editar")
  end
end
