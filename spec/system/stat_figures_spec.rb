require "rails_helper"

# A figure never breaks in two (Fernando, 2026-11-13: «−L» on one line and
# the amount on the next): it stays on one line and fits its card, whatever
# the screen's width.
RSpec.describe "Summary figures", type: :system do
  let(:admin) { create(:user, :admin) }

  before do
    create(:money_account, opening_balance: -2_558_979.59)
    sign_in_as(admin)
  end

  def figure_fit
    page.evaluate_script(<<~JS)
      (() => { const card = [...document.querySelectorAll(".stat")].find(el => el.querySelector("dd")?.textContent.includes("2,558,979.59"));
        const dd = card.querySelector("dd"), lineHeight = parseFloat(getComputedStyle(dd).lineHeight);
        return { lines: Math.round(dd.getBoundingClientRect().height / lineHeight), fits: dd.scrollWidth <= card.clientWidth } })()
    JS
  end

  [ [ 1280, 900 ], [ 390, 844 ] ].each do |width, height|
    it "keeps «−L 2,558,979.59» on one line inside its card at #{width} px" do
      page.driver.resize(width, height)
      visit root_path
      expect(page).to have_css(".stat dd", text: "−L 2,558,979.59")
      expect(figure_fit).to eq("lines" => 1, "fits" => true)
    end
  end
end
