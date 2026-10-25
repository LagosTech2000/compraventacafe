require "rails_helper"

# Paying a period of the Planilla interna: the totals follow what is typed
# (staff_payment_controller.js) and the receipt opens after paying.
RSpec.describe "Planilla interna payment", type: :system do
  let(:user) { create(:user, :admin) }
  let!(:account) { create(:money_account, name: "Caja", default_for: %w[cash]) }

  before { sign_in_as(user) }

  it "previews salary, overtime, goals, a free bonus and the advances, then pays" do
    member = create(:staff_member, role: create(:staff_role, salary: 6_000, overtime_hour_rate: 50), starts_on: Time.zone.today - 40)
    period = member.period_to_pay
    create(:staff_goal, member:, period_starts_on: period.starts_on, description: "Inventario", bonus_amount: 300)
    create(:staff_advance, member:, given_on: period.starts_on, amount: 1_000, money_account: account)

    visit new_finance_staff_member_staff_payment_path(member)
    net = "[data-staff-payment-target='net']"
    expect(page).to have_css(net, text: "L 5,000.00")

    fill_in "staff_payment_overtime_hours", with: "2"
    expect(page).to have_css(net, text: "L 5,100.00")
    check "Inventario"
    expect(page).to have_css(net, text: "L 5,400.00")
    fill_in "staff_payment_extra_bonus", with: "100"
    expect(page).to have_css(net, text: "L 5,500.00")
    expect(find_field("staff_payment_extra_bonus_reason")[:required]).to be(true)
    fill_in "staff_payment_extra_bonus_reason", with: "Puntual"

    click_button "Pagar"
    expect(page).to have_text("Período pagado.")
    expect(page).to have_text("Recibo de pago de planilla")
    expect(StaffPayment.sole).to have_attributes(net_total: 5_500, extra_bonus_reason: "Puntual")
  end
end
