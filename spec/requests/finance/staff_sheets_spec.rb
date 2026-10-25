require "rails_helper"

# The payroll sheet of the Planilla interna (Fernando, 2026-10-25): the
# Excel's fortnight, the month and the history; paying together.
RSpec.describe "Finance staff sheet" do
  include ActiveSupport::Testing::TimeHelpers

  let(:admin) { create(:user, :admin) }
  let!(:account) { create(:money_account, name: "Caja", default_for: %w[cash]) }
  let(:role) { create(:staff_role, name: "Chofer", salary: 15_000, pay_frequency: "biweekly") }

  def page = Nokogiri::HTML(response.body)

  around { |example| travel_to(Time.zone.local(2026, 10, 20, 10)) { example.run } }

  before { sign_in admin }

  def employee(first_names, days:, salary: nil)
    member = create(:staff_member, role:, salary_override: salary, starts_on: Date.new(2026, 10, 1),
                                   person: create(:person, :collaborator, first_names:, last_names: "Demo"))
    days.each { |day| member.attendances.create!(worked_on: Date.new(2026, 10, day), day_fraction: 1) }
    member
  end

  it "shows the fortnight like the Excel and pays the marked ones together" do
    alejandro = employee("Alejandro", days: 3..14)
    create(:staff_advance, member: alejandro, given_on: Date.new(2026, 10, 5), amount: 1_500, money_account: account)
    david = employee("David", days: 1..15, salary: 7_000)

    get finance_staff_sheet_path(month: "2026-10", half: 1)
    expect(page.at_css("#sheet_staff_member_#{alejandro.id}").text.squish).to include("Alejandro Demo", "12", "L 6,000.00", "−L 1,500.00", "L 4,500.00", "Por pagar")
    expect(page.at_css("#sheet_staff_member_#{david.id}").text.squish).to include("15", "L 3,500.00")
    expect(page.at_css("tfoot").text.squish).to include("27", "L 9,500.00", "L 8,000.00")
    expect(page.css("input[name='member_ids[]']").size).to eq(2)

    post pay_finance_staff_sheet_path(month: "2026-10", half: 1), params: { member_ids: [ alejandro.id, david.id ], paid_on: "2026-10-16",
                                                                           payment_method: "cash", money_account_id: account.id }
    expect(flash[:notice]).to eq("Se pagó la quincena a 2 empleados.")
    expect(StaffPayment.order(:id).map(&:net_total)).to eq([ 4_500, 3_500 ])

    get finance_staff_sheet_path(month: "2026-10", half: 1)
    expect(page.css("input[name='member_ids[]']")).to be_empty
    expect(page.at_css("#sheet_staff_member_#{david.id} button.day-toggle")["disabled"]).to be_present # a paid period stays
  end

  it "shows the month and the history of the season" do
    member = employee("Bayron", days: 1..20)
    issuer = StaffPaymentIssuer.new(member:, period: member.period_to_pay, user: admin, payment_method: "cash", money_account_id: account.id)
    issuer.call

    get finance_staff_sheet_path(view: "month", month: "2026-10")
    expect(page.at_css("#month_staff_member_#{member.id}").text.squish).to include("15 5 20", "L 10,000.00", "L 7,500.00")

    get finance_staff_sheet_path(view: "history")
    row = page.at_css("#history_staff_member_#{member.id}").text.squish
    expect(row).to include("Bayron Demo", "L 7,500.00", "L 15,000.00")
  end

  it "lets a reader see it but not mark attendance nor pay" do
    member = employee("Kevin", days: [])
    reader = create(:user).tap { create(:permission, user: it, module_key: "finance", can_read: true) }
    sign_in reader
    get finance_staff_sheet_path(month: "2026-10", half: 1)
    expect(response).to have_http_status(:ok)
    expect(page.at_css("#sheet_staff_member_#{member.id} button.day-toggle")["disabled"]).to be_present
    patch finance_staff_sheet_path(month: "2026-10", half: 1), params: { work: { member.id.to_s => { "2026-10-02" => "1" } } }
    expect(response).to redirect_to(root_path)
    expect(member.attendances.count).to eq(0)
  end
end
