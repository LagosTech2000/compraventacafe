require "rails_helper"

# Advances of buyers and banks (Fernando, 2026-10-25; 2026-11-16): money that
# comes in without interest, registered without a sale and applied later to
# one or several sales by a % of it, or given back in money. Pending until
# that covers it, then cancelled.
RSpec.describe "Sales buyer advances" do
  let(:admin) { create(:user, :admin) }
  let(:buyer) { create(:buyer, name: "Exportadora Norte") }
  let!(:bank) { create(:money_account, name: "Banco", kind: "bank", bank_key: "bac", default_for: %w[transfer]) }

  def page = Nokogiri::HTML(response.body)

  def sale_of(buyer, total:)
    shipment = create(:shipment, :received, buyer:)
    SaleIssuer.new(buyer:, user: admin, shipment_ids: [ shipment.id ], payment_status: "pending",
                   sale: { price_unit: "pound", unit_price: (total / shipment.destination_net_weight).round(6).to_s, quintal_pounds: "120" }).call.sale
  end

  before { sign_in admin }

  it "registers an advance of a buyer or a bank from the list, that comes into the account and shows in Ingresos" do
    lender = create(:buyer, name: "Banco Atlántida", kind: "bank")
    post sales_buyer_advances_path, params: { buyer_advance: { buyer_id: lender.id, amount: "20000", received_on: Time.zone.today, payment_method: "transfer",
                                                               money_account_id: bank.id, document_number: "TR-55" } }
    advance = BuyerAdvance.sole
    expect(response).to redirect_to(sales_buyer_buyer_advance_path(lender, advance))
    expect(advance).to have_attributes(buyer: lender, status: "pending")
    expect(lender.advance_balance).to eq(20_000)
    expect(AccountBalance.new.for(bank)).to eq(bank.opening_balance + 20_000)

    get sales_buyer_buyer_advance_path(lender, advance)
    expect(page.css("article").size).to eq(2)
    expect(page.css("article").first.text.squish).to include("Recibo de anticipo", "Banco Atlántida", "TR-55", "L 20,000.00")
    expect(page.at_css("[data-advance-figure=status]").text).to include("Pendiente")

    get sales_buyer_advances_path(status: "pending")
    expect(page.css("[data-buyer-advances] tbody tr").map { it.text.squish }).to contain_exactly(a_string_including("Banco Atlántida", "Banco", "Pendiente"))
    expect(page.at_css("[data-advance-total=balance] dd").text).to eq("L 20,000.00")

    get finance_incomes_path
    expect(response.body).to include("Anticipo #{advance.display_number} de comprador")
  end

  it "applies a % of it to several sales of any buyer, each collected «con anticipo», and is cancelled with a refund" do
    lender = create(:buyer, name: "Banco Atlántida", kind: "bank")
    advance = create(:buyer_advance, buyer: lender, amount: 10_000, money_account: bank)
    first = sale_of(buyer, total: 6_000)
    second = sale_of(create(:buyer), total: 8_000)

    get new_sales_advance_application_path(advance_id: advance.id)
    expect(page.css("[data-advance-application-choices] tbody tr").size).to eq(2)

    post sales_advance_applications_path, params: { advance_id: advance.id, applied_on: Time.zone.today,
                                                    shares: { first.id => { chosen: "1", percent: "40" }, second.id => { chosen: "1", percent: "30" } } }
    expect(response).to redirect_to(sales_buyer_buyer_advance_path(lender, advance))
    expect(advance.reload.applications.map { [ it.sale, it.amount ] }).to contain_exactly([ first, 4_000 ], [ second, 3_000 ])
    expect(first.reload).to have_attributes(payment_status: "partial", paid_total: 4_000)
    expect(first.payments.sole).to have_attributes(payment_method: "advance", money_account_id: nil)
    expect(advance).to have_attributes(status: "pending", balance: 3_000, free_percent: 30)
    # No money moved: the advance's money already came in.
    expect(MoneyMovements.new.all.map(&:source)).not_to include("sale_payments")

    # Never over what is free of the advance, nor over what a sale owes.
    post sales_advance_applications_path, params: { advance_id: advance.id, shares: { second.id => { chosen: "1", percent: "50" } } }
    expect(flash[:alert]).to include("pasa de lo libre del anticipo (30%)")
    third = sale_of(buyer, total: 1_000)
    post sales_advance_applications_path, params: { advance_id: advance.id, shares: { third.id => { chosen: "1", percent: "20" } } }
    expect(flash[:alert]).to include("pasa de lo que falta por cobrar de la venta")
    expect(advance.reload.applications.count).to eq(2)

    get sales_sale_path(first)
    expect(response.body).to include("Del anticipo #{advance.display_number} · Banco Atlántida")

    post sales_buyer_buyer_advance_refunds_path(lender, advance), params: { buyer_advance_refund: { amount: "3000", refunded_on: Time.zone.today,
                                                                                                 payment_method: "transfer", money_account_id: bank.id } }
    expect(advance.reload).to have_attributes(status: "cancelled", cancelled_on: Time.zone.today, balance: 0)
    expect(AccountBalance.new.for(bank)).to eq(bank.opening_balance + 10_000 - 3_000)
    expect(MoneyMovements.new.all.find { it.source == "buyer_advance_refunds" }).to have_attributes(amount_out: 3_000)

    # Removing what was applied gives it back to the advance, pending again.
    application = advance.applications.find_by(sale: second)
    delete sales_advance_application_path(application)
    expect(advance.reload).to have_attributes(status: "pending", balance: 3_000)
    expect(second.reload.payments).to be_empty
    # So does removing its collection from the sale.
    delete sales_sale_payment_path(first, first.payments.sole)
    expect(advance.reload.applications).to be_empty
    expect(advance.balance).to eq(7_000)
  end

  it "applies the pending advances from a sale, never over what it owes" do
    sale = sale_of(buyer, total: 5_000)
    one = create(:buyer_advance, buyer:, amount: 4_000, money_account: bank)
    two = create(:buyer_advance, buyer: create(:buyer, kind: "bank"), amount: 2_000, money_account: bank)

    get new_sales_advance_application_path(sale_id: sale.id)
    expect(page.css("[data-advance-application-choices] tbody tr").size).to eq(2)

    post sales_advance_applications_path, params: { sale_id: sale.id, shares: { one.id => { chosen: "1", percent: "100" }, two.id => { chosen: "1", percent: "100" } } }
    expect(flash[:alert]).to include("pasa de lo que falta por cobrar de la venta")
    expect(sale.reload.payments).to be_empty

    post sales_advance_applications_path, params: { sale_id: sale.id, shares: { one.id => { chosen: "1", percent: "100" }, two.id => { chosen: "1", percent: "50" } } }
    expect(response).to redirect_to(sales_sale_path(sale))
    expect(sale.reload).to have_attributes(payment_status: "paid", paid_total: 5_000)
    expect(one.reload.status).to eq("cancelled")
    expect(two.reload).to have_attributes(status: "pending", balance: 1_000)
  end

  it "takes «con anticipo» only through an application, and keeps an advance in use" do
    sale = sale_of(buyer, total: 5_000)
    advance = create(:buyer_advance, buyer:, amount: 1_000, money_account: bank)
    post sales_sale_payments_path(sale), params: { sale_payment: { amount: "500", paid_on: Time.zone.today, payment_method: "advance" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("«Con anticipo» solo sale al aplicar un anticipo a la venta")

    BuyerAdvanceSale.create!(buyer_advance: advance, sale:, percent: 10, applied_on: Time.zone.today, created_by: admin)
    expect(BuyerAdvancePolicy.new(admin, advance.reload).destroy?).to be(false)
  end

  it "is seen by who reads Compradores; applying it takes editing Ventas too" do
    advance = create(:buyer_advance, buyer:, amount: 1_000, money_account: bank)
    sale = sale_of(buyer, total: 2_000)
    reader = create(:user).tap { create(:permission, user: it, module_key: "sales", submodule_key: "buyers", can_read: true) }
    sign_in reader
    get sales_buyer_advances_path
    expect(response).to have_http_status(:ok)
    post sales_advance_applications_path, params: { advance_id: advance.id, shares: { sale.id => { chosen: "1", percent: "10" } } }
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")
  end
end
