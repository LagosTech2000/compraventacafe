require "rails_helper"

RSpec.describe "Farm payrolls" do
  let(:user) { create(:user) }

  describe PayPeriod do
    def periods(frequency, starts_on: Date.new(2026, 2, 4), ends_on: Date.new(2026, 3, 20))
      payroll = build(:payroll, pay_frequency: frequency, starts_on:, ends_on:)
      PayPeriod.for(payroll, through: Date.new(2026, 12, 31)).map { |period| [ period.starts_on, period.ends_on ] }
    end

    it "ends weekly periods on Saturday, starting on the payroll's first day" do
      expect(periods("weekly").first(2)).to eq([ [ Date.new(2026, 2, 4), Date.new(2026, 2, 7) ], [ Date.new(2026, 2, 8), Date.new(2026, 2, 14) ] ])
      expect(periods("weekly").last).to eq([ Date.new(2026, 3, 15), Date.new(2026, 3, 20) ])
    end

    it "never ends a period the day it starts: a payroll starting on payday runs to the next one" do
      expect(periods("weekly", starts_on: Date.new(2026, 10, 10), ends_on: Date.new(2026, 10, 31))).to eq([ # Saturday
        [ Date.new(2026, 10, 10), Date.new(2026, 10, 17) ], [ Date.new(2026, 10, 18), Date.new(2026, 10, 24) ],
        [ Date.new(2026, 10, 25), Date.new(2026, 10, 31) ]
      ])
      expect(periods("biweekly", starts_on: Date.new(2026, 10, 15), ends_on: Date.new(2026, 11, 15)).first).to eq([ Date.new(2026, 10, 15), Date.new(2026, 10, 31) ])
      expect(periods("weekly", starts_on: Date.new(2026, 10, 10), ends_on: Date.new(2026, 10, 10))).to eq([ [ Date.new(2026, 10, 10), Date.new(2026, 10, 10) ] ])
    end

    it "pays biweekly on the 15th and the last day of the month, February included" do
      expect(periods("biweekly")).to eq([
        [ Date.new(2026, 2, 4), Date.new(2026, 2, 15) ], [ Date.new(2026, 2, 16), Date.new(2026, 2, 28) ],
        [ Date.new(2026, 3, 1), Date.new(2026, 3, 15) ], [ Date.new(2026, 3, 16), Date.new(2026, 3, 20) ]
      ])
    end

    it "pays monthly at the end of the month" do
      expect(periods("monthly", ends_on: nil).first(2)).to eq([ [ Date.new(2026, 2, 4), Date.new(2026, 2, 28) ], [ Date.new(2026, 3, 1), Date.new(2026, 3, 31) ] ])
    end

    it "lists only the periods that have started" do
      payroll = build(:payroll, pay_frequency: "weekly", starts_on: Date.new(2026, 10, 1))
      expect(PayPeriod.for(payroll, through: Date.new(2026, 10, 5)).map(&:ends_on)).to eq([ Date.new(2026, 10, 3), Date.new(2026, 10, 10) ])
    end
  end

  describe "daily payroll" do
    let(:payroll) { create(:payroll, kind: "daily", starts_on: Date.new(2026, 9, 1)) }
    let(:worker) { create(:payroll_role, payroll:, name: "Jornalero", daily_wage: 300) }
    let(:foreman) { create(:payroll_role, payroll:, name: "Caporal", daily_wage: 450) }
    let(:period) { payroll.period_containing(Date.new(2026, 9, 1)) } # Tue 1 – Sat 5

    it "pays days × the role's wage, or the member's own wage when set" do
      ana = create(:payroll_member, payroll:, role: worker)
      luis = create(:payroll_member, payroll:, role: foreman, daily_wage_override: 500)
      [ 1, 2, 3 ].each { |day| create_attendance(ana, day) }
      create_attendance(ana, 4, 0.5)
      create_attendance(luis, 1)

      lines = payroll.calculation(period).lines.to_h { |line| [ line.member, [ line.quantity, line.rate, line.gross_amount ] ] }
      expect(lines[ana]).to eq([ 3.5, 300, 1_050 ])
      expect(lines[luis]).to eq([ 1, 500, 500 ])
    end

    it "requires a role or an own wage, and a collaborator, in Spanish" do
      member = build(:payroll_member, payroll:, role: nil, person: create(:person))
      expect(member.tap(&:valid?).errors.full_messages).to include(
        "Asígnale un rol o un salario propio: en una planilla por día cada empleado necesita su salario.",
        "Colaborador debe tener el rol de colaborador"
      )
    end

    it "pays a period with loan payments taken from the pay, all or nothing" do
      ana = create(:payroll_member, payroll:, role: worker)
      5.times { |index| create_attendance(ana, index + 1) } # 1 500
      loan = create(:loan, person: ana.person, cash_amount: 2_000, monthly_interest_rate: 0, disbursed_on: Date.new(2026, 8, 1))

      too_much = issuer(loan_amounts: { loan.id => 1_600 })
      expect(too_much.save).to be(false)
      expect(too_much.errors.full_messages.first).to include("se le descuenta más de lo que gana")
      expect(PayrollPayment.count).to eq(0)

      expect(issuer(loan_amounts: { loan.id => "400" }).save).to be(true)
      payment = payroll.payments.last
      expect(payment).to have_attributes(gross_total: 1_500, loans_total: 400, net_total: 1_100)
      expect(loan.payments.last).to have_attributes(amount: 400, payment_method: "payroll", payroll_payment_line: payment.lines.first)
      expect(issuer.save).to be(false) # already paid
    end

    it "closes a paid period, and reopens it when the latest payment is removed" do
      ana = create(:payroll_member, payroll:, role: worker)
      attendance = create_attendance(ana, 1)
      issuer.save
      payment = payroll.payments.last

      expect(attendance.update(day_fraction: 0.5)).to be(false)
      expect(attendance.errors.full_messages).to include("Día es de un período ya pagado")
      expect(attendance.destroy).to be(false)
      expect(PayrollAttendance.new(member: ana, worked_on: Date.new(2026, 9, 2), day_fraction: 1)).not_to be_valid

      expect(payment).to be_removable
      payment.remove!
      expect(attendance.reload.update(day_fraction: 0.5)).to be(true)
    end

    it "recalculates the unpaid periods when the frequency or dates change, keeping the paid ones" do
      create_attendance(create(:payroll_member, payroll:, role: worker), 1)
      issuer.save # Tue 1 – Sat 5 Sep, weekly

      payroll.update!(pay_frequency: "biweekly")
      ranges = payroll.reload.periods(through: Date.new(2026, 10, 20)).map { |period| [ period.starts_on, period.ends_on ] }
      expect(ranges.first(3)).to eq([
        [ Date.new(2026, 9, 1), Date.new(2026, 9, 5) ], [ Date.new(2026, 9, 6), Date.new(2026, 9, 15) ], [ Date.new(2026, 9, 16), Date.new(2026, 9, 30) ]
      ])
      expect(payroll.payment_for(payroll.periods.first)).to be_present

      payroll.update!(pay_frequency: "monthly", ends_on: Date.new(2026, 9, 20))
      expect(payroll.reload.periods(through: Date.new(2026, 10, 20)).last.dates).to eq(Date.new(2026, 9, 6)..Date.new(2026, 9, 20))
    end

    it "keeps the kind once paid, and dates that cover what was recorded, in Spanish" do
      create_attendance(create(:payroll_member, payroll:, role: worker), 3)
      expect(payroll.update(starts_on: Date.new(2026, 9, 4))).to be(false)
      expect(payroll.errors.full_messages).to include("Fecha de inicio no puede ser después del 03/09/2026: ese día ya hay trabajo o un pago registrado")
      expect(payroll.reload.update(ends_on: Date.new(2026, 9, 2))).to be(false)

      payroll.reload
      expect(issuer.save).to be(true)
      expect(payroll.reload.update(kind: "harvest", can_price: 10)).to be(false)
      expect(payroll.errors.full_messages).to include("Tipo ya no se puede cambiar: la planilla tiene pagos")
    end

    def create_attendance(member, day, fraction = 1)
      PayrollAttendance.create!(member:, worked_on: Date.new(2026, 9, day), day_fraction: fraction)
    end

    def issuer(loan_amounts: {})
      PayrollPaymentIssuer.new(payroll:, period:, user:, paid_on: Date.new(2026, 9, 5), loan_amounts:, with_loans: true)
    end
  end

  it "pays a harvest payroll by cans × the can price" do
    payroll = create(:payroll, kind: "harvest", can_price: 25, starts_on: Date.new(2026, 9, 1))
    member = create(:payroll_member, payroll:)
    HarvestEntry.create!(member:, worked_on: Date.new(2026, 9, 1), cans: 12)
    HarvestEntry.create!(member:, worked_on: Date.new(2026, 9, 2), cans: 8.5)

    line = payroll.calculation(payroll.period_containing(Date.new(2026, 9, 1))).lines.sole
    expect([ line.quantity, line.rate, line.gross_amount ]).to eq([ 20.5, 25, 512.5 ])
    expect(build(:payroll, kind: "harvest", can_price: nil)).not_to be_valid
  end

  it "pays the foremen of a harvest payroll by day (their role's wage) and the pickers by cans" do
    payroll = create(:payroll, kind: "harvest", can_price: 25, starts_on: Date.new(2026, 9, 1))
    foreman = create(:payroll_member, payroll:, role: create(:payroll_role, payroll:, name: "Caporal", daily_wage: 400))
    picker = create(:payroll_member, payroll:)
    PayrollAttendance.create!(member: foreman, worked_on: Date.new(2026, 9, 1), day_fraction: 1)
    PayrollAttendance.create!(member: foreman, worked_on: Date.new(2026, 9, 2), day_fraction: 0.5)
    HarvestEntry.create!(member: picker, worked_on: Date.new(2026, 9, 1), cans: 10)
    period = payroll.period_containing(Date.new(2026, 9, 1))

    lines = payroll.calculation(period).lines.to_h { |line| [ line.member, [ line.basis, line.quantity, line.rate, line.gross_amount ] ] }
    expect(lines[foreman]).to eq([ "daily", 1.5, 400, 600 ])
    expect(lines[picker]).to eq([ "harvest", 10, 25, 250 ])

    expect(HarvestEntry.new(member: foreman, worked_on: Date.new(2026, 9, 3), cans: 5)).not_to be_valid
    expect(PayrollAttendance.new(member: picker, worked_on: Date.new(2026, 9, 3), day_fraction: 1)).not_to be_valid
    expect(foreman.update(role: nil)).to be(false)
    expect(picker.update(daily_wage_override: 300)).to be(false)
    expect(picker.errors.full_messages).to include(a_string_starting_with("Ya tiene latas registradas"))

    PayrollPaymentIssuer.new(payroll:, period:, user: create(:user), paid_on: period.ends_on).save
    expect(payroll.payments.sole.lines.to_h { |line| [ line.member, line.basis ] }).to eq(foreman => "daily", picker => "harvest")
  end

  it "splits a task in equal parts, the leftover cents to the first by name, paid in its completion period" do
    payroll = create(:payroll, kind: "task", starts_on: Date.new(2026, 9, 1))
    members = %w[Alvarado Bonilla Castro].map { |last_names| create(:payroll_member, payroll:, person: create(:person, :collaborator, last_names:)) }
    task = payroll.tasks.create!(name: "Chapia lote 2", amount: 1_000, member_ids: members.map(&:id), completed_on: Date.new(2026, 9, 3))
    payroll.tasks.create!(name: "Sin terminar", amount: 500, member_ids: [ members.first.id ])

    expect(task.shares.values).to eq([ 333.34, 333.33, 333.33 ].map { |amount| BigDecimal(amount.to_s) })
    lines = payroll.calculation(payroll.period_containing(Date.new(2026, 9, 3))).lines
    expect(lines.sum(&:gross_amount)).to eq(1_000)
    expect(lines.map(&:quantity)).to eq([ 1, 1, 1 ])

    unfinished = payroll.tasks.new(name: "Sin gente", amount: 10, completed_on: Date.new(2026, 9, 3))
    expect(unfinished.tap(&:valid?).errors.full_messages).to include("Marca quiénes hicieron la tarea antes de darla por terminada.")
  end

  it "pays a one-day task the same day: 1 000 among 4 is 250 each" do
    today = Time.zone.today
    payroll = create(:payroll, kind: "task", starts_on: today, ends_on: today)
    members = create_list(:payroll_member, 4, payroll:)
    payroll.tasks.create!(name: "Chapia", amount: 1_000, member_ids: members.map(&:id), completed_on: today)

    period = payroll.periods_to_pay.sole
    expect([ period.starts_on, period.ends_on ]).to eq([ today, today ])
    expect(payroll.calculation(period).lines.map(&:gross_amount)).to eq([ 250 ] * 4)
  end

  it "makes a period due on its last day, its payday" do
    payroll = build(:payroll, pay_frequency: "weekly", starts_on: Date.new(2026, 10, 5)) # Monday
    period = payroll.periods(through: Date.new(2026, 10, 10)).sole
    expect(period.due?(Date.new(2026, 10, 9))).to be(false)
    expect(period.due?(Date.new(2026, 10, 10))).to be(true) # Saturday
  end

  it "lists the periods to come as upcoming, up to the end date (or just the next one)" do
    payroll = create(:payroll, starts_on: Date.new(2026, 10, 10), ends_on: Date.new(2026, 10, 31))
    rows = payroll.period_rows(Date.new(2026, 10, 10))
    expect(rows.map { |row| [ row.period.starts_on.day, row.status ] }).to eq([ [ 25, "upcoming" ], [ 18, "upcoming" ], [ 10, "in_progress" ] ])

    payroll.update!(ends_on: nil)
    expect(payroll.period_rows(Date.new(2026, 10, 10)).map { |row| row.period.starts_on.day }).to eq([ 18, 10 ])
  end

  it "keeps the payroll's accounts: pay plus expenses" do
    payroll = create(:payroll)
    create(:payroll_expense, payroll:, amount: 700)
    expect(payroll.total_cost).to eq(700)
    expect(build(:payroll_expense, payroll:, category: create(:expense_category, active: false))).not_to be_valid
  end
end
