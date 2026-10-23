require "rails_helper"

# Work forms ask before their changes are lost (Fernando, 2026-10-18): on
# leaving the page and on closing the window they are in.
RSpec.describe "Unsaved changes", type: :system do
  let(:user) { create(:user, :admin) }

  before { sign_in_as(user) }

  it "asks before closing the window with a purchase half written, and keeps it if the answer is no" do
    visit trading_purchases_path
    find("a[data-turbo-frame=modal]", text: "Nueva compra").click
    within("dialog[open]") { fill_in "purchase_gross_weight", with: "330" }

    message = dismiss_confirm { within("dialog[open]") { find("[data-action~='modal#close']", match: :first).click } }
    expect(message).to eq("Tienes cambios sin guardar en este formulario. ¿Salir sin guardar?")
    expect(page).to have_field("purchase_gross_weight", with: "330")

    accept_confirm { within("dialog[open]") { find("[data-action~='modal#close']", match: :first).click } }
    expect(page).to have_no_css("dialog[open]")
  end

  it "asks before leaving a loan half written, and not once it is sent" do
    visit new_loans_loan_path
    fill_in "loan_cash_amount", with: "1000"

    dismiss_confirm { click_link "Estados de cuenta", match: :first }
    expect(page).to have_current_path(new_loans_loan_path)

    accept_confirm { click_link "Estados de cuenta", match: :first }
    expect(page).to have_current_path(loans_credit_accounts_path)
  end

  it "does not ask when nothing changed" do
    visit new_loans_loan_path
    click_link "Estados de cuenta", match: :first

    expect(page).to have_current_path(loans_credit_accounts_path)
  end
end
