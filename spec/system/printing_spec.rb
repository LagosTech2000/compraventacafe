require "rails_helper"

# Printed documents (print media): the business letterhead on top, and
# nothing of the screen on paper (buttons, help).
RSpec.describe "Printing", type: :system do
  let(:user) { create(:user, :admin) }

  def print_media = page.driver.browser.page.command("Emulation.setEmulatedMedia", media: "print")
  def visible?(selector) = page.evaluate_script("[...document.querySelectorAll(#{selector.to_json})].some((el) => el.offsetParent !== null)")

  before { sign_in_as(user) }

  it "prints a credit account with the letterhead and without buttons" do
    loan = create(:loan, cash_amount: 1_000, monthly_interest_rate: 0)
    visit loans_credit_account_path(loan.person)
    expect(page).to have_css(".btn")
    print_media

    expect(visible?(".btn")).to be(false)
    expect(visible?(".help-button")).to be(false)
    expect(page).to have_css("header", text: "Estado de cuenta", visible: :all)
    expect(visible?("header.border-b-2")).to be(true)
  end
end
