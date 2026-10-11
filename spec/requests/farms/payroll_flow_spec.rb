require "rails_helper"

RSpec.describe "Farms flow" do
  let(:admin) { create(:user, :admin) }
  let(:today) { Time.zone.today }

  before { sign_in admin }

  it "creates a farm and a daily payroll, adds people, records attendance and pays with a loan deduction" do
    post farms_farms_path, params: { farm: { name: "El Roble" } }
    farm = Farm.last
    post farms_payrolls_path, params: { payroll: { farm_id: farm.id, name: "Limpia", kind: "daily", pay_frequency: "weekly",
                                                   starts_on: today.beginning_of_week - 7 } }
    payroll = Payroll.last
    expect(response).to redirect_to(farms_payroll_path(payroll, tab: "members"))

    post farms_payroll_roles_path(payroll), params: { payroll_role: { name: "Jornalero", daily_wage: "300" } }
    person = create(:person, :collaborator)
    post farms_payroll_members_path(payroll), params: { payroll_member: { person_id: person.id, payroll_role_id: payroll.roles.last.id } }
    member = payroll.members.last
    expect(member.daily_wage).to eq(300)

    period = payroll.periods.first
    patch farms_payroll_timesheet_path(payroll, period: period.to_param),
          params: { work: { member.id.to_s => { period.starts_on.iso8601 => "1", (period.starts_on + 1).iso8601 => "0.5" } } }
    expect(response).to redirect_to(farms_payroll_timesheet_path(payroll, period: period.to_param))
    expect(member.attendances.sum(:day_fraction)).to eq(1.5)

    get farms_payroll_timesheet_path(payroll, period: period.to_param)
    expect(response.body).to include("L 450.00")

    loan = create(:loan, person:, cash_amount: 1_000, monthly_interest_rate: 0, disbursed_on: today - 30)
    get new_farms_payroll_payment_path(payroll, period: period.to_param)
    expect(response.body).to include("Préstamo #{loan.id}", "L 450.00")

    post farms_payroll_payments_path(payroll, period: period.to_param),
         params: { payroll_payment_issuer: { paid_on: today, loan_amounts: { loan.id => "100" } } }
    payment = payroll.reload.payments.last
    expect(response).to redirect_to(farms_payroll_payment_path(payroll, payment))
    expect(payment).to have_attributes(gross_total: 450, loans_total: 100, net_total: 350)

    get farms_payroll_payment_path(payroll, payment)
    expect(response.body).to include(person.full_name, "1.5 días × L 300.00", "L 350.00")

    get loans_loan_path(loan)
    expect(response.body).to include("Descuento de planilla · Limpia")

    get farms_payroll_timesheet_path(payroll, period: period.to_param)
    expect(response.body).to include("Este período ya se pagó")
    expect(Nokogiri::HTML(response.body).css("select[name^='work']").all? { |cell| cell["disabled"] }).to be(true)

    delete farms_payroll_payment_path(payroll, payment)
    expect([ PayrollPayment.count, loan.payments.count ]).to eq([ 0, 0 ])
  end

  it "shows the new periods right after editing the payroll in the modal" do
    payroll = create(:payroll, pay_frequency: "weekly", starts_on: Date.new(2026, 9, 1))
    patch farms_payroll_path(payroll), params: { payroll: { pay_frequency: "monthly" } }, headers: { "Turbo-Frame" => "modal" }
    expect(response.body).to include('data-modal-result-refresh-value="true"')

    get farms_payroll_path(payroll)
    periods = Nokogiri::HTML(response.body).css("tr[id^='period_'] td:first-child").map(&:text)
    expect(periods.last).to eq("1 de sep – 30 de sep")
  end

  it "lists what is left to pay on the module home" do
    payroll = create(:payroll, starts_on: today - 20)
    member = create(:payroll_member, payroll:)
    PayrollAttendance.create!(member:, worked_on: payroll.periods.first.starts_on, day_fraction: 1)

    get farms_root_path
    main = Nokogiri::HTML(response.body).at_css("main").text
    expect(main).to include(payroll.name, "L 300.00")
  end

  it "records cans and tasks" do
    harvest = create(:payroll, kind: "harvest", can_price: 30, starts_on: today)
    picker = create(:payroll_member, payroll: harvest)
    foreman = create(:payroll_member, payroll: harvest, role: create(:payroll_role, payroll: harvest, name: "Caporal", daily_wage: 400))
    get farms_payroll_timesheet_path(harvest)
    page = Nokogiri::HTML(response.body)
    expect(page.css("main h2").map(&:text)).to eq([ "Cortadores (por latas)", "Caporales (salario por día)" ])
    expect(page.at_css("select[name='work[#{foreman.id}][#{today.iso8601}]']")).to be_present
    expect(page.at_css("input[name='work[#{picker.id}][#{today.iso8601}]']")).to be_present

    patch farms_payroll_timesheet_path(harvest, period: today.iso8601),
          params: { work: { picker.id.to_s => { today.iso8601 => "10" }, foreman.id.to_s => { today.iso8601 => "1" } } }
    expect(picker.harvest_entries.sole.cans).to eq(10)
    expect(foreman.attendances.sole.day_fraction).to eq(1)
    expect(harvest.calculation(harvest.period_containing(today)).gross_total).to eq(700)

    by_task = create(:payroll, kind: "task", starts_on: today)
    workers = create_list(:payroll_member, 2, payroll: by_task)
    post farms_payroll_tasks_path(by_task), params: { payroll_task: { name: "Chapia", amount: "900", completed_on: today, member_ids: workers.map(&:id) } }
    expect(by_task.tasks.sole.shares.values).to eq([ 450, 450 ])
  end

  it "shows timesheet errors in Spanish without saving any cell" do
    payroll = create(:payroll, starts_on: today)
    member = create(:payroll_member, payroll:)
    patch farms_payroll_timesheet_path(payroll, period: today.iso8601), params: { work: { member.id.to_s => { today.iso8601 => "3" } } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Asistencia no está incluido en la lista")
    expect(PayrollAttendance.count).to eq(0)
  end

  it "renders every screen of the module, as a page and in the modal" do
    daily = create(:payroll, starts_on: today - 10, ends_on: today + 30)
    member = create(:payroll_member, payroll: daily)
    PayrollAttendance.create!(member:, worked_on: daily.periods.first.starts_on, day_fraction: 1)
    PayrollPaymentIssuer.new(payroll: daily, period: daily.periods.first, user: admin).save
    harvest = create(:payroll, kind: "harvest", starts_on: today)
    by_task = create(:payroll, kind: "task", starts_on: today)
    task = by_task.tasks.create!(name: "Chapia", amount: 100, member_ids: [ create(:payroll_member, payroll: by_task).id ])
    expense = create(:payroll_expense, payroll: daily)

    paths = [ farms_root_path, farms_farms_path, new_farms_farm_path, farms_farm_path(daily.farm), edit_farms_farm_path(daily.farm),
              farms_payrolls_path, new_farms_payroll_path, edit_farms_payroll_path(daily),
              new_farms_payroll_role_path(daily), edit_farms_payroll_role_path(daily, member.role),
              new_farms_payroll_member_path(daily), edit_farms_payroll_member_path(daily, member),
              farms_payroll_timesheet_path(daily), farms_payroll_timesheet_path(daily, day: today.iso8601), farms_payroll_timesheet_path(harvest),
              new_farms_payroll_task_path(by_task), edit_farms_payroll_task_path(by_task, task),
              new_farms_payroll_payment_path(daily, period: daily.periods.last.to_param), farms_payroll_payment_path(daily, daily.payments.first),
              new_farms_payroll_expense_path(daily), edit_farms_payroll_expense_path(daily, expense),
              farms_expense_categories_path, new_farms_expense_category_path, edit_farms_expense_category_path(expense.category) ]
    paths += [ daily, harvest, by_task ].flat_map do |payroll|
      %w[periods members tasks expenses].map { |tab| farms_payroll_path(payroll, tab:) }
    end

    paths.each do |path|
      [ {}, { "Turbo-Frame" => "modal" } ].each do |headers|
        get(path, headers:)
        expect(response).to have_http_status(:ok), "#{path} #{headers}"
      end
    end
  end

  it "takes loans permission to deduct loans, and keeps a read-only user from changing anything" do
    payroll = create(:payroll, starts_on: today)
    member = create(:payroll_member, payroll:)
    PayrollAttendance.create!(member:, worked_on: today, day_fraction: 1)
    loan = create(:loan, person: member.person, disbursed_on: today - 10)

    clerk = create(:user).tap { |u| create(:permission, user: u, module_key: "farms", can_read: true, can_create: true, can_update: true) }
    sign_in clerk
    get new_farms_payroll_payment_path(payroll, period: today.iso8601)
    expect(response.body).not_to include("Préstamo #{loan.id}")
    post farms_payroll_payments_path(payroll, period: today.iso8601), params: { payroll_payment_issuer: { paid_on: today, loan_amounts: { loan.id => "50" } } }
    expect(payroll.reload.payments.sole.loans_total).to eq(0)

    reader = create(:user).tap { |u| create(:permission, user: u, module_key: "farms", can_read: true) }
    sign_in reader
    get farms_payroll_timesheet_path(payroll)
    expect(response).to have_http_status(:ok)
    patch farms_payroll_timesheet_path(payroll), params: { work: {} }
    expect(response).to redirect_to(root_path)
    post farms_payrolls_path, params: { payroll: { name: "X" } }
    expect(Payroll.count).to eq(1)
  end
end
