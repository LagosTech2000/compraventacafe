require "rails_helper"

# Amounts show their commas while typed (Fernando, 2026-11-14; thousands.js),
# and the gross and net pounds of Salidas go one below the other where they do
# not fit side by side (format_gross_net, .gross-net).
RSpec.describe "Amounts and pounds on screen", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  def shown(id) = page.evaluate_script(<<~JS)
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").get.call(document.getElementById("#{id}"))
  JS

  it "puts the commas while typing, keeps the field's decimals and sends the plain number" do
    box = create(:money_account, name: "Caja", default_for: %w[cash])
    create(:finance_category, name: "Transporte")
    visit new_finance_expense_path

    fill_in "expense_amount", with: "1234567.891"
    expect(shown("expense_amount")).to eq("1,234,567.89")
    expect(find_field("expense_amount").value).to eq("1234567.89")

    find_field("expense_amount").send_keys(:home, "-")
    expect(shown("expense_amount")).to eq("1,234,567.89")

    fill_in "expense_amount", with: "0"
    expect(page.evaluate_script("document.getElementById('expense_amount').validationMessage")).to eq("Escribe 0.01 o más.")

    fill_in "expense_amount", with: "12500.5"
    expect(shown("expense_amount")).to eq("12,500.5")
    fill_in "expense_description", with: "Diésel del camión"
    select "Transporte", from: "expense_finance_category_id"
    click_button "Registrar gasto"
    expect(page).to have_text("Gasto registrado")
    expect(Expense.last).to have_attributes(amount: 12_500.5, money_account: box)
  end

  it "leaves percents as they are" do
    create(:permission, user:, module_key: "trading", can_read: true, can_create: true)
    visit new_trading_purchase_path
    expect(page).to have_css("input#purchase_humidity_percent[type=number]", visible: :all)
    expect(page).to have_css("input#purchase_price_per_pound[data-thousands]")
  end

  it "puts the net pounds below the gross where both do not fit" do
    create(:shipment, origin_gross_weight: 123_456.78)
    page.driver.resize(380, 900)
    visit sales_shipments_path

    stat = find(".stat", text: "BÁSCULA LOCAL", match: :first)
    tops = stat.all(".gross-net > span").map { it.evaluate_script("this.getBoundingClientRect().top") }
    expect(tops.size).to eq(2)
    expect(tops.last).to be > tops.first
    expect(stat.evaluate_script("this.scrollWidth <= this.clientWidth")).to be(true)
  ensure
    page.driver.resize(1400, 1000)
  end
end
