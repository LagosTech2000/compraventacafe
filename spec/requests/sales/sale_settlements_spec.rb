require "rails_helper"

# The buyer's settlement (Fernando, 2026-10-25): what the buyer pays per
# its own liquidation; from then on it is what the sale collects.
RSpec.describe "Sales buyer settlement" do
  let(:admin) { create(:user, :admin) }
  let(:sale) { create(:sale) } # L 24,108

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "enters the buyer's total and reason, and the sale shows and collects it" do
    get edit_sales_sale_settlement_path(sale)
    expect(response).to have_http_status(:ok)

    patch sales_sale_settlement_path(sale), params: { sale: { buyer_total: "23000", buyer_total_reason: "Calidad" } }
    expect(response).to redirect_to(sales_sale_path(sale))
    expect(sale.reload).to have_attributes(buyer_total: 23_000, buyer_total_reason: "Calidad", balance_due: 23_000)
    expect(AuditEvent.where(auditable: sale, action: "update")).to exist

    get sales_sale_path(sale)
    expect(page.at_css("[data-settlement-difference]").text.squish).to include("L 23,000.00", "L 1,108.00 menos", "Calidad")
    expect(page.at_css("[data-buyer-settlement]").text.squish).to include("Liquidación del comprador (Calidad)", "L 23,000.00")
    expect(page.at_css("[data-weight-difference-money]").text.squish).to include("4.90 lb menos", "L 245.00")
  end

  it "asks for the reason and keeps the form" do
    patch sales_sale_settlement_path(sale), params: { sale: { buyer_total: "23000", buyer_total_reason: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(sale.reload.buyer_total).to be_nil
  end
end
