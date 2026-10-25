require "rails_helper"

RSpec.describe "Control financiero" do
  include ActiveSupport::Testing::TimeHelpers
  describe MoneyMovements do
    it "puts together every module's money, each once, with its account" do
      bank = create(:money_account, kind: "bank")
      producer = create(:producer)
      invoice = create(:invoice, producer:)
      invoice.payments.create!(amount: 100, paid_on: Time.zone.today, payment_method: "cash", created_by: create(:user), money_account: bank)
      create(:loan_payment, loan: create(:loan, person: producer.person, cash_amount: 3_000), amount: 50, payment_method: "transfer")
      create(:loan_payment, loan: create(:loan, person: producer.person), amount: 20, payment_method: "coffee", purchase: create(:purchase, producer:))
      create(:sale_payment, sale: create(:sale), amount: 70)
      create(:expense, amount: 30, money_account: bank)
      create(:expense, kind: "investment", amount: 900)
      create(:other_income, amount: 5)
      create(:account_transfer, amount: 7)

      sources = described_class.new.all.map(&:source)
      expect(sources.tally).to include("invoices" => 1, "loans" => 2, "loan_payments" => 1, "sale_payments" => 1,
                                       "expenses" => 1, "investments" => 1, "other_incomes" => 1, "transfers" => 2)
      expect(described_class.new(account: bank.id).all.map(&:source)).to contain_exactly("invoices", "expenses")
      expect(described_class.new(account: :none).all.map(&:source)).not_to include("transfers", "expenses")
    end

    it "gives each movement its date at the hour it was registered, and lists them by that moment" do
      travel_to(Time.zone.local(2026, 10, 20, 15, 30)) { create(:other_income, concept: "Tarde", received_on: Date.new(2026, 10, 20)) }
      travel_to(Time.zone.local(2026, 10, 21, 8, 5)) { create(:other_income, concept: "Mañana", received_on: Date.new(2026, 10, 20)) }
      movements = described_class.new(range: Date.new(2026, 10, 20)..Date.new(2026, 10, 20)).all
      expect(movements.map(&:description)).to eq(%w[Mañana Tarde])
      expect(movements.map { it.at.strftime("%d %H:%M") }).to eq([ "20 08:05", "20 15:30" ])
    end

    it "only gives each user the sources of the modules they read" do
      user = create(:user).tap { create(:permission, user: it, module_key: "finance", can_read: true) }
      expect(described_class.sources_for(user)).to eq(%w[expenses investments staff_payments staff_advances other_incomes transfers])
    end
  end

  describe MoneyAccount do
    it "takes its bank from Honduras' main banks or typed by hand, and its card follows it" do
      ficohsa = create(:money_account, kind: "bank", bank_key: "ficohsa", bank_name: "lo que sea", account_number: "2100 4455 1234")
      expect(ficohsa).to have_attributes(bank_name: "Ficohsa", card_style: "ficohsa", masked_number: "•••• 1234")
      other = create(:money_account, kind: "bank", bank_key: "other", bank_name: "Banpaís")
      expect(other.bank_name).to eq("Banpaís")
      expect(HondurasBank::OTHER_STYLES).to include(other.card_style)
      expect(build(:money_account, kind: "bank", bank_key: "other", bank_name: "")).not_to be_valid
      expect(build(:money_account, kind: "bank", bank_key: nil)).not_to be_valid
      expect(HondurasBank.all.values).to eq([ "Ficohsa", "Banco Atlántida", "BAC Honduras", "Banco de Occidente" ])
    end
  end

  describe AccountBalance do
    it "adds the opening balance, what came in and minus what went out, up to a day" do
      box = create(:money_account, opening_balance: 1_000)
      create(:expense, money_account: box, amount: 200, spent_on: Time.zone.today)
      create(:other_income, money_account: box, amount: 50, received_on: Time.zone.yesterday)
      create(:account_transfer, from_account: box, amount: 100)
      expect(described_class.new.for(box)).to eq(750)
      expect(described_class.new(as_of: Time.zone.yesterday).for(box)).to eq(1_050)
    end
  end

  describe FinanceCategory do
    it "has two levels, its parent's kind, and unique names within a parent" do
      transport = create(:finance_category, name: "Transporte")
      fuel = create(:finance_category, name: "Combustible", parent: transport)
      expect(fuel.full_name).to eq("Transporte › Combustible")
      expect(build(:finance_category, name: "Algo", parent: fuel)).not_to be_valid
      expect(build(:finance_category, name: "combustible", parent: transport)).not_to be_valid
      expect(build(:finance_category, name: "Combustible")).to be_valid
      expect(FinanceCategory.options_for("expense").map(&:first)).to eq([ "Transporte", "Transporte › Combustible" ])
    end
  end

  describe Expense do
    it "takes a category of its kind and an active account, and a PDF as receipt" do
      expense = build(:expense, category: create(:finance_category, kind: "investment"))
      expect(expense).not_to be_valid
      expect(expense.errors[:category]).to be_present
      expect(build(:expense, money_account: create(:money_account, active: false))).not_to be_valid

      pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 demo"), "application/pdf", original_filename: "factura.pdf")
      expense = create(:expense, receipt_upload: pdf)
      expect(expense.receipt).to have_attributes(content_type: "application/pdf", filename: "factura.pdf")
    end
  end

  describe BudgetSheet do
    it "compares each first-level category's budget with its family's spending by month" do
      transport = create(:finance_category, name: "Transporte")
      month = Time.zone.today.beginning_of_month
      create(:budget, category: transport, month:, amount: 1_000)
      create(:expense, category: create(:finance_category, name: "Diésel", parent: transport), amount: 800)
      line = BudgetSheet.new.line(transport, month)
      expect([ line.budget, line.spent, line.percent, line.over? ]).to eq([ 1_000, 800, 80, false ])
      expect(BudgetSheet.new.months.first).to eq(Season.current.starts_on)
    end
  end
end
