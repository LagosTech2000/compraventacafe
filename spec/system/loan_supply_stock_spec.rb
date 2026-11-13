require "rails_helper"

# «Nuevo préstamo» says when a supply is lent without stock (Fernando,
# 2026-11-13): it is lent anyway and what is missing stays to be delivered.
RSpec.describe "Lending supplies without stock", type: :system do
  let(:user) { create(:user, :admin) }
  let(:urea) { create(:supply, name: "Urea", unit: "sacos", default_price: 900) }

  before do
    create(:supply_entry, supply: urea, quantity: 20, amount: 18_000)
    sign_in_as(user)
  end

  def line = all("[data-loan-composition-target~='item']").last

  it "warns a line, or several of the same supply together, that lend more than is available" do
    visit new_loans_loan_path
    click_button "Agregar insumo"
    within(line) do
      select "Urea (disponible: 20 sacos)", from: find("select")[:id]
      find("input[data-loan-composition-target~='quantity']").fill_in(with: "15")
      expect(page).to have_no_css("[data-no-stock]", visible: true)
    end

    click_button "Agregar insumo"
    within(line) do
      select "Urea (disponible: 20 sacos)", from: find("select")[:id]
      find("input[data-loan-composition-target~='quantity']").fill_in(with: "10")
    end
    expect(page).to have_css("[data-no-stock]", count: 2,
                                                text: "Sin existencias de Urea: hay 20 sacos disponibles. Se presta igual: 5 sacos no se podrán entregar hasta que entren más.")

    within(line) { find("input[data-loan-composition-target~='quantity']").fill_in(with: "5") }
    expect(page).to have_no_css("[data-no-stock]", visible: true)
  end

  it "counts what the loan itself lent when it is edited" do
    loan = build(:loan, disbursed_on: Time.zone.today, due_on: Time.zone.today + 60)
    loan.supply_items.build(supply: urea, quantity: 20, unit_price: 900)
    loan.save!
    visit edit_loans_loan_path(loan)
    expect(page).to have_no_css("[data-no-stock]", visible: true)
    find("input[data-loan-composition-target~='quantity']").fill_in(with: "21")
    expect(page).to have_css("[data-no-stock]", text: "hay 20 sacos disponibles")
  end
end
