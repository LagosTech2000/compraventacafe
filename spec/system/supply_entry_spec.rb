require "rails_helper"

# An entry of supplies with several lines (Fernando, 2026-11-13): lines are
# added in place, a supply created in the modal joins them, and the total
# (the investment) follows.
RSpec.describe "Supply entry", type: :system do
  let(:admin) { create(:user, :admin) }

  it "adds lines, creates a supply in the modal and registers the entry" do
    create(:supply, name: "Urea", unit: "saco")
    create(:finance_category, kind: "investment", name: "Insumos")
    create(:money_account, name: "Caja")
    sign_in_as(admin)
    visit new_sales_supply_entry_path

    lines = -> { all("[data-supply-entry-target~='line']") }
    expect(lines.call.size).to eq(1)
    within(lines.call.first) do
      select "Urea (saco)", from: find("select")[:id]
      find("input[name$='[quantity]']").fill_in(with: "20")
      find("input[name$='[amount]']").fill_in(with: "16000")
    end

    click_link "Nuevo insumo"
    within("dialog[open]") do
      fill_in "supply_name", with: "Fungicida"
      fill_in "supply_unit", with: "litro"
      fill_in "supply_default_price", with: "300"
      find("[type=submit]").click
    end
    expect(page).to have_no_css("dialog[open]")
    expect(lines.call.size).to eq(2)
    within(lines.call.last) do
      expect(find("select").value).to eq(Supply.find_by!(name: "Fungicida").id.to_s)
      find("input[name$='[quantity]']").fill_in(with: "5")
      find("input[name$='[amount]']").fill_in(with: "1500")
    end
    expect(page).to have_css("[data-supply-entry-target=total]", text: "L 17,500.00")

    select "Insumos", from: "supply_entry_finance_category_id"
    select "Caja", from: "supply_entry_money_account_id"
    click_button "Registrar entrada"
    expect(page).to have_text("Entrada de Urea y Fungicida registrada, con su inversión.")
    expect(SupplyEntry.last.lines.count).to eq(2)
  end
end
