require "rails_helper"

# Planilla interna on screen: roles, employees, advances, goals and the
# payment of a period with its receipt.
RSpec.describe "Finance staff payroll" do
  include ActiveSupport::Testing::TimeHelpers

  let(:admin) { create(:user, :admin) }
  let!(:account) { create(:money_account, name: "Caja", default_for: %w[cash]) }

  def page = Nokogiri::HTML(response.body)

  around { |example| travel_to(Time.zone.local(2026, 10, 20, 10)) { example.run } }

  before { sign_in admin }

  it "goes from a role and an employee to a paid period with its receipt" do
    post finance_staff_roles_path, params: { staff_role: { name: "Bodeguero", salary: "6000", pay_frequency: "biweekly", overtime_hour_rate: "50" } }
    role = StaffRole.sole
    person = create(:person, :collaborator, first_names: "Marta", last_names: "Cruz")
    post finance_staff_members_path, params: { staff_member: { person_id: person.id, staff_role_id: role.id, starts_on: "2026-10-01" } }
    member = StaffMember.sole
    expect(response).to redirect_to(finance_staff_member_path(member))

    get finance_staff_members_path
    expect(response).to have_http_status(:ok)
    expect(page.at_css("#staff_member_#{member.id}").text.squish).to include("Marta Cruz", "Bodeguero", "L 6,000.00", "Por pagar")
    expect(page.css(".stat").map { it.text.squish }).to include("Períodos por pagar1")

    post finance_staff_member_staff_advances_path(member), params: { staff_advance: { amount: "1000", given_on: "2026-10-10", payment_method: "cash", money_account_id: account.id } }
    get new_finance_staff_member_staff_goal_path(member)
    expect(response).to have_http_status(:ok)
    post finance_staff_member_staff_goals_path(member), params: { staff_goal: { period_starts_on: "2026-10-01", description: "Inventario al día", bonus_amount: "300" } }
    goal = StaffGoal.sole

    get finance_staff_member_path(member)
    expect(response.body).to include("Inventario al día", "Por descontar", "Pagar 1 de oct – 15 de oct")

    get new_finance_staff_member_staff_payment_path(member)
    expect(response).to have_http_status(:ok)
    expect(page.at_css("[data-staff-payment-target='net']").text).to eq("L 5,000.00")

    post finance_staff_member_staff_payments_path(member), params: { staff_payment: {
      salary: "6000", overtime_hours: "2", met_goal_ids: [ goal.id.to_s ], extra_bonus: "", paid_on: "2026-10-20",
      payment_method: "cash", money_account_id: account.id
    } }
    payment = StaffPayment.sole
    expect(response).to redirect_to(finance_staff_member_staff_payment_path(member, payment))
    expect(payment).to have_attributes(gross_total: 6_400, advances_total: 1_000, net_total: 5_400)

    get finance_staff_member_staff_payment_path(member, payment)
    receipt = page.css("article")
    expect(receipt.size).to eq(2)
    expect(receipt.first.text.squish).to include("Marta Cruz", "Horas extra: 2 × L 50.00", "Bono por meta: Inventario al día", "Anticipo del 10/10/2026", "Se le entregaL 5,400.00")
    expect(AuditEvent.where(auditable: payment, action: "create")).to exist

    get finance_movements_path
    expect(response.body).to include("Pago de planilla interna", "Anticipo de planilla interna")

    delete finance_staff_member_staff_payment_path(member, payment)
    expect(StaffPayment.count).to eq(0)
    expect(goal.reload.met).to be_nil
  end

  it "does not pay a period that has not started, nor lets a reader pay" do
    member = create(:staff_member, starts_on: Date.new(2026, 11, 1))
    get new_finance_staff_member_staff_payment_path(member)
    expect(response).to redirect_to(finance_staff_member_path(member))

    reader = create(:user).tap { create(:permission, user: it, module_key: "finance", can_read: true) }
    sign_in reader
    get finance_staff_member_path(member)
    expect(response).to have_http_status(:ok)
    post finance_staff_member_staff_payments_path(member), params: { staff_payment: { salary: "1" } }
    expect(response).to redirect_to(root_path)
  end

  it "shows a role without salary and pays nobody in it until it has one" do
    role = create(:staff_role, name: "Bodeguero", salary: nil, pay_frequency: nil)
    member = create(:staff_member, role:, starts_on: Date.new(2026, 10, 1))

    get finance_staff_roles_path
    expect(page.at_css("#staff_role_#{role.id}").text.squish).to include("Bodeguero", "Sin salario")
    get finance_staff_member_path(member)
    expect(response.body).to include("El rol Bodeguero todavía no tiene salario", "Poner el salario")
    get new_finance_staff_member_staff_payment_path(member)
    expect(response).to redirect_to(finance_staff_member_path(member))
    expect(flash[:alert]).to include("El rol Bodeguero todavía no tiene salario")

    patch finance_staff_role_path(role), params: { staff_role: { salary: "4000", pay_frequency: "biweekly" } }
    get new_finance_staff_member_staff_payment_path(member)
    expect(response).to have_http_status(:ok)
  end

  it "edits a role and an employee, and removes a role nobody used" do
    role = create(:staff_role)
    get edit_finance_staff_role_path(role)
    expect(response.body).to include("Quitar el rol")
    patch finance_staff_role_path(role), params: { staff_role: { salary: "7000", pay_frequency: "monthly" } }
    expect(role.reload).to have_attributes(salary: 7_000, pay_frequency: "monthly")
    get finance_staff_roles_path
    expect(page.at_css("#staff_role_#{role.id}").text.squish).to include("L 7,000.00", "Mensual")

    member = create(:staff_member)
    get edit_finance_staff_member_path(member)
    patch finance_staff_member_path(member), params: { staff_member: { active: "0", ends_on: "2026-10-31" } }
    expect(member.reload).to have_attributes(active: false, ends_on: Date.new(2026, 10, 31))

    unused = create(:staff_role)
    delete finance_staff_role_path(unused)
    expect(StaffRole.exists?(unused.id)).to be(false)
  end
end
