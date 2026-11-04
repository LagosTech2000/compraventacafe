require "rails_helper"

# The loans module's collection screens (Fernando, 2026-11-03): Cobrar con
# café, Calendario de cobro, Cartera, Por cosecha, Cierre diario and the
# Simulador.
RSpec.describe "Loans collection screens" do
  let(:admin) { create(:user, :admin) }
  let(:today) { Time.zone.today }
  let(:zone) { create(:zone, name: "El Zarzal") }
  let(:producer) { create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya", phone: "99990000", zone:)) }

  def page = Nokogiri::HTML(response.body)
  def dom_id(...) = ActionView::RecordIdentifier.dom_id(...)

  before { sign_in admin }

  describe "Cobrar con café" do
    it "lists who owes with the purchases whose money can still pay, and opens the pago con café" do
      loan = create(:loan, person: producer.person, due_on: today - 3)
      free = create(:purchase, producer:)
      paid_out = create(:purchase, producer:)
      InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ paid_out.id ], payment_status: "paid", payment_method: "cash").call
      create(:purchase) # someone who owes nothing

      get loans_coffee_collection_path
      expect(response).to have_http_status(:ok)
      row = page.at_css("##{dom_id(producer.person, :coffee_collection)}")
      expect(row.text).to include("Ana Zelaya", "El Zarzal", "9999-0000", "1 vencido", "Compra #{free.id}", "L 4,120.90")
      expect(row.text).not_to include("Compra #{paid_out.id}")
      expect(row.at_css("a[href='#{new_trading_purchase_loan_settlement_path(free)}']").text).to eq("Abonar con café")
      expect(page.css("tbody tr").size).to eq(1)
      expect(response.body).to include(format("L %s", ActiveSupport::NumberHelper.number_to_delimited(loan.balance.total_owed.round(2).to_s("F"))))
    end

    it "takes only what a purchase still has after its loan payments" do
      loan = create(:loan, person: producer.person)
      purchase = create(:purchase, producer:)
      create(:loan_payment, loan:, purchase:, payment_method: "coffee", amount: 4_000)

      get loans_coffee_collection_path
      expect(page.at_css("##{dom_id(producer.person, :coffee_collection)}").text).to include("L 120.90")
      expect(purchase.reload.available_for_loans_loaded).to eq(purchase.available_for_loans)
    end

    it "narrows to the purchases of a period" do
      create(:loan, person: producer.person)
      old = create(:purchase, producer:, purchased_at: 10.days.ago)

      get loans_coffee_collection_path(period: "week")
      expect(page.css("tbody tr")).to be_empty
      get loans_coffee_collection_path(period: "month")
      expect(response.body).to include("Compra #{old.id}")
    end

    it "takes seeing Compra de café too, and creating in Préstamos to pay" do
      reader = create(:user)
      reader.permissions.create!(module_key: "loans", can_read: true)
      sign_in reader
      get loans_coffee_collection_path
      expect(response).to redirect_to(root_path)

      reader.permissions.create!(module_key: "trading", can_read: true)
      create(:loan, person: producer.person)
      create(:purchase, producer:)
      get loans_coffee_collection_path
      expect(response).to have_http_status(:ok)
      expect(page.css("a").map(&:text)).not_to include("Abonar con café")
    end
  end

  describe "Calendario de cobro" do
    it "puts the late loans apart and each week with its loans, phone and actions" do
      late = create(:loan, person: producer.person, due_on: today - 5)
      soon = create(:loan, due_on: today.end_of_week + 3)

      get loans_collection_calendar_path
      expect(response).to have_http_status(:ok)
      late_bucket = page.at_css("#calendar-bucket-late")
      expect(late_bucket.text).to include("Vencidos", "1 préstamo")
      # This week has nothing: the late loans open first.
      expect(page.at_css("##{dom_id(late, :calendar)}").text).to include("Ana Zelaya", "9999-0000", "hace 5 días")

      week = (today.beginning_of_week + 7).iso8601
      get loans_collection_calendar_path(week:)
      expect(page.at_css("#calendar-bucket-#{week}")["aria-current"]).to eq("true")
      row = page.at_css("##{dom_id(soon, :calendar)}")
      expect(row.at_css("a[href='#{new_loans_loan_payment_path(soon)}']")).to be_present
      expect(page.at_css("##{dom_id(late, :calendar)}")).to be_nil
    end

    it "leaves out paid loans" do
      loan = create(:loan, due_on: today + 1)
      create(:loan_payment, loan:, amount: loan.balance.total_owed)

      get loans_collection_calendar_path
      expect(page.at_css("##{dom_id(loan, :calendar)}")).to be_nil
    end
  end

  describe "Cartera" do
    it "sums what is owed by tramo and by zone, and links each tramo to its loans" do
      create(:loan, person: producer.person, cash_amount: 1_000, monthly_interest_rate: 0, due_on: today - 45)
      create(:loan, cash_amount: 2_000, monthly_interest_rate: 0, due_on: today + 10)
      create(:loan, cash_amount: 4_000, monthly_interest_rate: 0, due_on: today + 90)

      get loans_portfolio_path
      expect(response).to have_http_status(:ok)
      expect(page.at_css("#portfolio-bucket-late_60").text).to include("L 1,000.00")
      expect(page.at_css("#portfolio-bucket-due_soon").text).to include("L 2,000.00")
      expect(page.at_css("#portfolio-bucket-current").text).to include("L 4,000.00")
      expect(page.at_css("#portfolio-zone-#{zone.id}").text).to include("El Zarzal", "L 1,000.00")
      expect(page.at_css("#portfolio-zone-none").text).to include("Sin zona", "L 6,000.00")

      link = page.at_css("#portfolio-bucket-late_60 a")["href"]
      get link
      expect(page.css("tbody tr").size).to eq(1)
      expect(response.body).to include("Ana Zelaya", "Vence desde el")
    end
  end

  describe "Por cosecha" do
    it "puts each loan in the season of its date and links to its loans" do
      create(:loan, person: producer.person, disbursed_on: Date.new(2026, 8, 31), due_on: Date.new(2026, 12, 31), cash_amount: 1_000)
      newer = create(:loan, disbursed_on: Date.new(2026, 9, 1), due_on: Date.new(2026, 12, 31), cash_amount: 3_000, monthly_interest_rate: 0)
      create(:loan_payment, loan: newer, paid_on: Date.new(2026, 10, 1), amount: 1_500)

      get loans_seasons_path
      expect(response).to have_http_status(:ok)
      expect(page.at_css("#loan-season-2025").text).to include("2025-2026", "L 1,000.00")
      season = page.at_css("#loan-season-2026").text
      expect(season).to include("2026-2027", "L 3,000.00", "L 1,500.00", "50.0%")

      get page.at_css("#loan-season-2026 a")["href"]
      expect(page.css("tbody tr").size).to eq(1)
      expect(response.body).to include("Cosecha: 2026-2027")
    end

    it "shows the season on the loan" do
      loan = create(:loan, disbursed_on: Date.new(2026, 9, 2), due_on: Date.new(2026, 12, 31))
      get loans_loan_path(loan)
      expect(response.body).to include("2026-2027")
    end
  end

  describe "Cierre diario" do
    it "shows what was lent and collected that day, by method and account, printable" do
      account = create(:money_account, name: "Caja préstamos")
      create(:loan, person: producer.person, disbursed_on: today, cash_amount: 5_000, money_account: account)
      loan = create(:loan, disbursed_on: today - 30)
      create(:loan_payment, loan:, amount: 800, money_account: account)
      purchase = create(:purchase, producer: create(:producer, person: loan.person))
      create(:loan_payment, loan:, amount: 200, payment_method: "coffee", purchase:)
      create(:loan, disbursed_on: today - 1, cash_amount: 999)

      get loans_daily_close_path(date: today.iso8601)
      expect(response).to have_http_status(:ok)
      expect(page.at_css("#close-method-cash").text).to include("L 800.00")
      expect(page.at_css("#close-method-coffee").text).to include("L 200.00")
      account_row = page.at_css("#close-account-#{account.id}").text
      expect(account_row).to include("L 5,000.00", "L 800.00", "-L 4,200.00").or include("L 5,000.00", "L 800.00", "L -4,200.00")
      expect(response.body).not_to include("L 999.00")
      expect(page.css("header.border-b-2").text).to include("Cierre diario de préstamos")
    end

    it "says when nothing happened" do
      get loans_daily_close_path(date: "2020-01-01")
      expect(response.body).to include("Ese día no hubo préstamos ni abonos.")
    end
  end

  describe "Simulador" do
    it "says what a loan would owe on a date, without saving" do
      expect {
        get loans_simulation_path(loan_simulation: { amount: "10000", monthly_interest_rate: "3", disbursed_on: "2026-11-01", paid_on: "2026-12-01" })
      }.not_to change(Loan, :count)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("L 10,300.00", "L 300.00", "L 10.00")
    end

    it "honors the intermediary grace days" do
      get loans_simulation_path(loan_simulation: { amount: "10000", monthly_interest_rate: "3", disbursed_on: "2026-11-01", paid_on: "2026-12-01", interest_grace: "1" })
      expect(response.body).to include("L 10,200.00")
    end

    it "explains a wrong date" do
      get loans_simulation_path(loan_simulation: { amount: "100", monthly_interest_rate: "3", disbursed_on: "2026-11-01", paid_on: "2026-10-01" })
      expect(response.body).to include("no puede ser antes de la fecha del préstamo")
    end

    it "starts empty" do
      get loans_simulation_path
      expect(response.body).to include("Escribe el monto, la tasa y las fechas")
    end
  end

  it "puts every screen in the module's bar" do
    get loans_root_path
    nav = page.at_css("nav.mb-5").text
    expect(nav).to include("Cobrar con café", "Calendario de cobro", "Cartera", "Por cosecha", "Cierre diario", "Simulador")
  end
end
