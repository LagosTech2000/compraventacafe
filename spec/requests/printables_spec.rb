require "rails_helper"

# Every printed document starts with the same letterhead
# (shared/_print_letterhead): the business and what the document is.
RSpec.describe "Printable documents" do
  let(:user) { create(:user, :admin) }
  let(:producer) { create(:producer) }

  before do
    sign_in user
    SiteSetting.current.update!(business_name: "Beneficio La Esperanza", location: "Marcala, La Paz")
  end

  def letterheads = Nokogiri::HTML(response.body).css("header.border-b-2")

  def expect_letterhead(title, count: 1)
    expect(letterheads.size).to eq(count)
    letterheads.each { |header| expect(header.text.squish).to include("Beneficio La Esperanza", "Marcala, La Paz", title) }
  end

  # Original and copy always print each on its own sheet (Fernando, 2026-10-16).
  def expect_copy_on_its_own_page
    copy = letterheads.find { |header| header.text.include?("COPIA") }
    expect(copy).to be_present
    expect(copy.ancestors.any? { |node| node["class"].to_s.split.include?("print:break-before-page") }).to be(true)
  end

  it "prints original and copy on separate sheets" do
    invoice = InvoiceIssuer.new(producer:, user:, purchase_ids: [ create(:purchase, producer:).id ], payment_status: "partial",
                                payment_method: "cash", amount: "1000").call.invoice
    loan = create(:loan, person: producer.person, cash_amount: 1_000, monthly_interest_rate: 0)
    loan_payment = create(:loan_payment, loan:, amount: 100, payment_method: "cash")

    hauler = create(:hauler)
    create(:purchase, hauler:)
    hauler_payment = create(:hauler_payment, hauler:, amount: 1)

    [ trading_invoice_path(invoice), trading_invoice_payment_path(invoice, invoice.payments.first),
      loans_loan_payment_path(loan, loan_payment), trading_hauler_payment_path(hauler, hauler_payment) ].each do |path|
      get path
      expect_copy_on_its_own_page
    end
  end

  it "puts it on invoices (original and copy) and their payment receipts" do
    invoice = InvoiceIssuer.new(producer:, user:, purchase_ids: [ create(:purchase, producer:).id ], payment_status: "partial",
                                payment_method: "cash", amount: "1000").call.invoice
    get trading_invoice_path(invoice)
    expect_letterhead("Factura #{invoice.display_number}", count: 2)
    expect(letterheads.map { |header| header.text.squish }).to all(include("Pago parcial"))

    get trading_invoice_payment_path(invoice, invoice.payments.first)
    expect_letterhead("Recibo de pago", count: 2)
  end

  it "puts it on loan payment receipts, payroll payment sheets, the daily close, credit accounts and reports" do
    loan = create(:loan, person: producer.person, cash_amount: 1_000, monthly_interest_rate: 0)
    payment = create(:loan_payment, loan:, amount: 100, payment_method: "cash")
    get loans_loan_payment_path(loan, payment)
    expect_letterhead("Recibo de abono", count: 2)

    payroll = create(:payroll, starts_on: Time.zone.today - 21)
    member = create(:payroll_member, payroll:)
    period = payroll.periods.first
    PayrollTimesheet.new(payroll, period).update(member.id.to_s => { period.starts_on.iso8601 => "1" })
    expect(PayrollPaymentIssuer.new(payroll:, period:, user:, paid_on: Time.zone.today).save).to be(true)
    get farms_payroll_payment_path(payroll, payroll.payments.last)
    expect_letterhead("Planilla de pago")

    get trading_daily_close_path
    expect_letterhead("Cierre diario")

    get loans_credit_account_path(producer.person)
    expect_letterhead("Estado de cuenta")
    expect(Nokogiri::HTML(response.body).at("main").text).not_to include("%>", "tabs:")

    get reports_report_path("purchases")
    expect_letterhead("Compras")
  end
end
