require "rails_helper"

# Advances of a buyer (Fernando, 2026-10-25): money that comes in and is
# paid back with coffee, without interest, taken off its sales.
RSpec.describe "Sales buyer advances" do
  let(:admin) { create(:user, :admin) }
  let(:buyer) { create(:buyer, name: "Exportadora Norte") }
  let!(:bank) { create(:money_account, name: "Banco", kind: "bank", bank_key: "bac", default_for: %w[transfer]) }

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "registers an advance that comes into the account and shows in Ingresos" do
    post sales_buyer_buyer_advances_path(buyer), params: { buyer_advance: { amount: "20000", received_on: Time.zone.today, payment_method: "transfer",
                                                                              money_account_id: bank.id, document_number: "TR-55" } }
    advance = BuyerAdvance.sole
    expect(response).to redirect_to(sales_buyer_path(buyer, tab: "advances", receipt: advance.id))
    expect(buyer.advance_balance).to eq(20_000)
    expect(AccountBalance.new.for(bank)).to eq(bank.opening_balance + 20_000)

    get sales_buyer_buyer_advance_path(buyer, advance)
    expect(page.css("article").size).to eq(2)
    expect(page.css("article").first.text.squish).to include("Recibo de anticipo", "Exportadora Norte", "TR-55", "L 20,000.00")

    get finance_incomes_path
    expect(response.body).to include("Anticipo de comprador", "Anticipo #{advance.display_number} de comprador")
  end

  it "takes part of a sale off the advances when selling, and the rest later «con anticipo»" do
    create(:buyer_advance, buyer:, amount: 5_000, money_account: bank)
    shipment = create(:shipment, :received, buyer:)

    get new_sales_sale_path(buyer_id: buyer.id)
    expect(response.body).to include("Descontar de anticipos (L)", "L 5,000.00")

    post sales_sales_path(buyer_id: buyer.id), params: { sale: { shipment_ids: [ shipment.id ], sold_on: Time.zone.today, price_unit: "quintal",
                                                                   unit_price: "6000", advance_amount: "3000", payment_status: "pending" } }
    sale = Sale.last
    expect(sale.payments.sole).to have_attributes(payment_method: "advance", amount: 3_000, money_account_id: nil)
    expect(sale.reload.payment_status).to eq("partial")
    expect(buyer.advance_balance).to eq(2_000)
    # No money moved: the advance's money already came in.
    expect(MoneyMovements.new.all.map(&:source)).not_to include("sale_payments")

    post sales_sale_payments_path(sale), params: { sale_payment: { amount: "2500", paid_on: Time.zone.today, payment_method: "advance", money_account_id: bank.id } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("es mayor que el saldo de anticipos del comprador (L 2,000.00)")

    post sales_sale_payments_path(sale), params: { sale_payment: { amount: "2000", paid_on: Time.zone.today, payment_method: "advance" } }
    expect(buyer.advance_balance).to eq(0)
    get sales_buyer_path(buyer, tab: "advances")
    expect(response.body).to include("Descontado de ventas", "−L 2,000.00", "−L 3,000.00")
    expect(page.css("button").map(&:text)).not_to include("Quitar") # used: it stays

    delete sales_sale_payment_path(sale, sale.payments.order(:id).last)
    expect(buyer.advance_balance).to eq(2_000)
  end

  it "cannot take more than the advances nor than what is owed when selling" do
    create(:buyer_advance, buyer:, amount: 1_000, money_account: bank)
    shipment = create(:shipment, :received, buyer:)
    post sales_sales_path(buyer_id: buyer.id), params: { sale: { shipment_ids: [ shipment.id ], sold_on: Time.zone.today, price_unit: "quintal",
                                                                   unit_price: "6000", advance_amount: "1500", payment_status: "pending" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(Sale.count).to eq(0)
  end
end
