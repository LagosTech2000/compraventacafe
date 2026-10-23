require "rails_helper"

# A person in several roles of a daily payroll, on the screens.
RSpec.describe "Payroll with a person in several roles" do
  let(:admin) { create(:user, :admin) }
  let(:payroll) { create(:payroll, name: "Limpia", kind: "daily", starts_on: Time.zone.today - 14) }
  let(:driver) { create(:payroll_role, payroll:, name: "Chofer", daily_wage: 400) }
  let(:laborer) { create(:payroll_role, payroll:, name: "Jornalero", daily_wage: 300) }
  let(:person) { create(:person, :collaborator, first_names: "Ana", last_names: "Zelaya") }
  let!(:as_driver) { create(:payroll_member, payroll:, person:, role: driver) }

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "adds the person again with another role from «Otro rol», and not with the same one" do
    get farms_payroll_path(payroll, tab: "members")
    expect(response.body).to include(new_farms_payroll_member_path(payroll, person_id: person.id))

    get new_farms_payroll_member_path(payroll, person_id: person.id)
    expect(response.body).to include("Ya está en esta planilla como Chofer")

    post farms_payroll_members_path(payroll), params: { payroll_member: { person_id: person.id, payroll_role_id: laborer.id } }
    expect(payroll.members.where(person:).count).to eq(2)

    post farms_payroll_members_path(payroll), params: { payroll_member: { person_id: person.id, payroll_role_id: driver.id } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("ya está en esta planilla con ese rol")
  end

  it "shows one card per person when paying, with each role, and one row in the loans tab" do
    as_laborer = create(:payroll_member, payroll:, person:, role: laborer)
    period = payroll.periods.first
    days = period.dates.to_a
    PayrollAttendance.create!(member: as_driver, worked_on: days[0], day_fraction: 1)
    PayrollAttendance.create!(member: as_laborer, worked_on: days[1], day_fraction: 1)
    create(:loan, person:, cash_amount: 1_000, monthly_interest_rate: 0)

    get new_farms_payroll_payment_path(payroll, period: period.to_param)
    cards = page.css("[data-payroll-payment-target~=line]")
    expect(cards.size).to eq(1)
    expect(cards.first["data-gross"]).to eq("700.0")
    expect(cards.first.text).to include("Chofer:", "Jornalero:", "L 700.00")

    get farms_payroll_path(payroll, tab: "loans")
    expect(page.css("#payroll-loans-list tbody tr").size).to eq(1)

    post farms_payroll_payments_path(payroll, period: period.to_param), params: { payroll_payment_issuer: { paid_on: period.ends_on } }
    payment = payroll.reload.payments.last
    get farms_payroll_payment_path(payroll, payment)
    expect(page.css("tbody tr").map(&:text).join).to include("Chofer", "Jornalero")
  end
end
