require "rails_helper"

RSpec.describe "Reports (data)" do
  let(:user) { create(:user, :admin) }
  let(:today) { Time.zone.today }

  def run(report_class, **params) = report_class.new(params, user:)
  def kpi(report, key) = report.kpis.find { |figure| figure.key == key }

  describe PurchasesReport do
    it "sums the period's purchases, without voided ones, and compares with the period before" do
      producer = create(:producer)
      create(:purchase, producer:, purchased_at: Time.current)
      create(:purchase, producer:, purchased_at: Time.current, price_per_pound: 60)
      create(:purchase, purchased_at: Time.current, voided_at: Time.current, voided_by: user)
      create(:purchase, purchased_at: 1.month.ago)

      report = run(PurchasesReport, period: "this_month")
      expect(report.total_count).to eq(2)
      expect(kpi(report, :count).value).to eq(2)
      expect(kpi(report, :quintals).value).to eq(BigDecimal("142.1") / 125)
      expect(kpi(report, :total).value).to eq(BigDecimal("4120.9") + BigDecimal("4263"))
      expect(kpi(report, :producers).value).to eq(1)
      expect(kpi(report, :count).previous).to eq(1)
      expect(kpi(report, :count).change).to eq(1)
    end

    it "counts a purchase on its day in Tegucigalpa, not in UTC" do
      late = Time.zone.local(2026, 10, 5, 23, 30) # 05:30 UTC of the 6th
      create(:purchase, purchased_at: late)

      expect(run(PurchasesReport, period: "custom", from: "2026-10-05", to: "2026-10-05").total_count).to eq(1)
      expect(run(PurchasesReport, period: "custom", from: "2026-10-06", to: "2026-10-06").total_count).to eq(0)
      grouped = run(PurchasesReport, period: "custom", from: "2026-10-01", to: "2026-10-10", group: "day")
      expect(grouped.page.first.map(&:key)).to eq([ Date.new(2026, 10, 5) ])
    end

    it "groups by producer, sorted by quintals, and filters by invoice status" do
      big = create(:producer)
      small = create(:producer)
      2.times { create(:purchase, producer: big) }
      create(:purchase, producer: small)
      create(:invoice, producer: small, purchases: [ create(:purchase, producer: small) ])

      rows, more = run(PurchasesReport, period: "this_month", group: "producer").page
      expect(more).to be(false)
      expect(rows.map(&:label)).to eq([ big.full_name, small.full_name ])
      expect(rows.map { |row| row["count"] }).to eq([ 2, 2 ])

      expect(run(PurchasesReport, period: "this_month", invoice_status: "uninvoiced").total_count).to eq(3)
      expect(run(PurchasesReport, period: "this_month", invoice_status: "pending").total_count).to eq(1)
    end

    it "pages 50 rows at a time, sorted by the chosen column" do
      producer = create(:producer)
      51.times { |n| create(:purchase, producer:, price_per_pound: 50 + n) }

      report = run(PurchasesReport, period: "this_month", sort: "price_per_pound", dir: "asc")
      rows, more = report.page
      expect([ rows.size, more ]).to eq([ 50, true ])
      expect(rows.first.price_per_pound).to eq(50)
      expect(report.page(2).first.map(&:price_per_pound)).to eq([ 100 ])
    end
  end

  it "shows what is left to pay on invoices, less the loans paid with coffee" do
    producer = create(:producer)
    purchase = create(:purchase, producer:)
    loan = create(:loan, person: producer.person, cash_amount: 1_000, monthly_interest_rate: 0)
    create(:loan_payment, loan:, amount: 500, payment_method: "coffee", purchase:)
    create(:invoice, producer:, purchases: [ purchase ])

    report = run(InvoicesReport, period: "this_month")
    expect(kpi(report, :total).value).to eq(BigDecimal("4120.9"))
    expect(kpi(report, :pending).value).to eq(BigDecimal("3620.9"))
    invoice = report.page.first.sole
    expect(InvoicesReport.columns.find { |column| column.key == :to_pay }.value.call(invoice)).to eq(BigDecimal("3620.9"))
  end

  describe "invoices paid in parts" do
    let(:producer) { create(:producer) }
    let(:invoice) { create(:invoice, producer:, purchases: [ create(:purchase, producer:) ]) }

    before do
      invoice.payments.create!(amount: 1_000, paid_on: today, payment_method: "cash", created_by: user)
      create(:invoice, producer:, purchases: [ create(:purchase, producer:) ]).mark_paid(method: "transfer", on: today)
    end

    it "shows what was paid and the balance, and filters by partial or unpaid" do
      report = run(InvoicesReport, period: "this_month")
      expect(kpi(report, :paid).value).to eq(BigDecimal("1000") + BigDecimal("4120.9"))
      expect(kpi(report, :pending).value).to eq(BigDecimal("3120.9"))
      expect(kpi(report, :pending_count).value).to eq(1)

      partial = run(InvoicesReport, period: "this_month", payment_status: "partial").page.first.sole
      expect(InvoicesReport.columns.find { |column| column.key == :balance }.value.call(partial)).to eq(BigDecimal("3120.9"))
      expect(run(InvoicesReport, period: "this_month", payment_status: "unpaid").total_count).to eq(1)
      expect(run(InvoicesReport, period: "this_month", payment_method: "cash").total_count).to eq(1)
    end

    it "takes out each payment on its own day in the money in and out" do
      by_source = run(CashMovementsReport, period: "today", group: "source").page.first.to_h { |row| [ row.key, row["amount_out"] ] }
      expect(by_source["invoices"]).to eq(BigDecimal("1000") + BigDecimal("4120.9"))
    end

    it "counts what is still owed to the producer, less what was paid" do
      create(:purchase, producer:) # not invoiced yet
      row = run(ProducersReport, period: "this_season").page.first.sole
      expect(ProducersReport.columns.find { |column| column.key == :pending }.value.call(row)).to eq(BigDecimal("3120.9") + BigDecimal("4120.9"))
    end

    it "shows the partial status of a purchase's invoice" do
      report = run(PurchasesReport, period: "this_month", invoice_status: "partial")
      expect(report.total_count).to eq(1)
    end
  end

  it "finds the producers who stopped selling" do
    selling = create(:producer)
    stopped = create(:producer)
    create(:purchase, producer: selling)
    create(:purchase, producer: stopped, purchased_at: 40.days.ago)

    report = run(ProducersReport, period: "last_30_days", activity: "without_purchases")
    rows = report.page.first
    expect(rows).to eq([ stopped ])
    expect(ProducersReport.columns.find { |column| column.key == :days_since }.value.call(rows.first)).to eq(40)
    expect(kpi(run(ProducersReport, period: "last_30_days"), :selling).value).to eq(1)
  end

  it "shows the loans' principal owed, what is owed today, and the overdue ones" do
    on_time = create(:loan, cash_amount: 10_000, monthly_interest_rate: 3, disbursed_on: today - 30, due_on: today + 30)
    create(:loan_payment, loan: on_time, amount: 1_300, paid_on: today)
    create(:loan, cash_amount: 2_000, monthly_interest_rate: 0, disbursed_on: today - 60, due_on: today - 5)

    report = run(LoansReport, period: "all")
    expect(kpi(report, :principal).value).to eq(12_000)
    expect(kpi(report, :owed).value).to eq(BigDecimal("11000"))
    expect(kpi(report, :balance).value).to eq(BigDecimal("11000"))
    expect(kpi(report, :overdue_owed).value).to eq(2_000)
    expect(run(LoansReport, period: "all", status: "overdue").total_count).to eq(1)
    expect(run(LoansReport, period: "all", due: "next_30_days").total_count).to eq(1)
  end

  it "adds the payrolls' expenses to their cost" do
    payroll = create(:payroll, kind: "daily", starts_on: today - 20)
    member = create(:payroll_member, payroll:)
    period = payroll.periods.first
    PayrollAttendance.create!(member:, worked_on: period.starts_on, day_fraction: 1)
    PayrollPaymentIssuer.new(payroll:, period:, user:, paid_on: today).save
    create(:payroll_expense, payroll:, amount: 700, spent_on: today)

    report = run(PayrollPaymentsReport, period: "this_month")
    expect(kpi(report, :expenses).value).to eq(700)
    expect(kpi(report, :total_cost).value).to eq(payroll.payments.sole.gross_total + 700)
  end

  it "counts cans, pickers and their value at the can price" do
    payroll = create(:payroll, kind: "harvest", can_price: 25, starts_on: today - 3)
    pickers = create_list(:payroll_member, 2, payroll:)
    HarvestEntry.create!(member: pickers.first, worked_on: today, cans: 10)
    HarvestEntry.create!(member: pickers.second, worked_on: today, cans: 6)

    report = run(HarvestReport, period: "today")
    expect([ kpi(report, :cans).value, kpi(report, :value).value, kpi(report, :pickers).value ]).to eq([ 16, 400, 2 ])
    expect(kpi(report, :average).value).to eq(8)
  end

  it "puts together the money in and out, without the payments that move no money" do
    producer = create(:producer)
    paid = create(:invoice, producer:, purchases: [ create(:purchase, producer:) ])
    paid.mark_paid(method: "cash", on: today)
    loan = create(:loan, person: producer.person, cash_amount: 3_000, monthly_interest_rate: 0, disbursed_on: today)
    create(:loan_payment, loan:, amount: 1_000, payment_method: "transfer", paid_on: today)
    create(:loan_payment, loan:, amount: 500, payment_method: "coffee", purchase: create(:purchase, producer:), paid_on: today)
    create(:payroll_expense, amount: 200, spent_on: today)

    report = run(CashMovementsReport, period: "today")
    expect(report.total_count).to eq(4)
    expect(kpi(report, :amount_in).value).to eq(1_000)
    expect(kpi(report, :amount_out).value).to eq(BigDecimal("4120.9") + 3_000 + 200)

    by_source = run(CashMovementsReport, period: "today", group: "source").page.first.to_h { |row| [ row.key, row["amount_out"] ] }
    expect(by_source).to include("invoices" => BigDecimal("4120.9"), "loans" => 3_000, "payroll_expenses" => 200)
  end

  it "joins what each person has with the business" do
    producer = create(:producer)
    create(:purchase, producer:)
    create(:loan, person: producer.person, cash_amount: 5_000)

    report = run(PeopleReport, period: "this_month")
    person = report.page.first.sole
    expect([ person.sales_total, person.owed_amount ]).to eq([ BigDecimal("4120.9"), 5_000 ])
    expect(PeopleReport.roles_of(person)).to eq("Productor · Con préstamos")
  end

  it "has suggested reports whose filters the reports understand" do
    ReportPreset.all.each do |preset|
      report = preset.report_class.new(preset.params)
      expect(report.filter.to_params.symbolize_keys).to include(preset.params), "#{preset.key}: #{report.filter.to_params}"
      expect(report.grouping&.key&.to_s).to eq(preset.params[:group]) if preset.params[:group]
      expect(report.sort_key).to eq(preset.params[:sort]) if preset.params[:sort]
      expect(I18n.exists?("reports.presets.#{preset.key}")).to be(true)
    end
  end
end
