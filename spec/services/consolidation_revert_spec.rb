require "rails_helper"
require "rake"

# Undoing a Consolidación done by mistake (Fernando, 2026-10-31).
RSpec.describe ConsolidationRevert do
  let(:user) { create(:user) }
  let!(:box) { create(:money_account, name: "Caja", kind: "cash", default_for: %w[cash]) }
  let(:bank) { create(:money_account, name: "Banco", kind: "bank") }

  def consolidate(request_id, **options)
    Current.request_id = request_id
    AccountConsolidation.new(**options).call
  ensure
    Current.reset
  end

  it "lists each consolidation and puts back the account and category it changed, only those" do
    invoice = create(:invoice)
    payment = invoice.payments.create!(amount: 10, paid_on: Time.zone.today, payment_method: "cash", created_by: user)
    loan = create(:loan, cash_amount: 500)
    expense = create(:payroll_expense, amount: 700)
    old_category = expense.category
    fuel = create(:expense_category, name: "Combustible")
    with_account = invoice.payments.create!(amount: 5, paid_on: Time.zone.today, payment_method: "cash", created_by: user, money_account: bank)

    consolidate("first", items: [ "invoices:#{payment.id}" ], by_method: true)
    consolidate("second", items: [ "loans:#{loan.id}", "payroll_expenses:#{expense.id}" ], account: bank, category: fuel)
    loan.reload.update!(money_account: box) # changed by hand later: left alone

    expect(described_class.groups.map(&:request_id)).to eq(%w[second first])
    expect(described_class.groups.first.events.size).to eq(2)

    revert = described_class.new([ "second" ])
    expect(revert.changes.map(&:record)).to eq([ expense ])
    expect(revert.apply!).to eq(1)
    expect(expense.reload).to have_attributes(money_account: nil, category: old_category)
    expect(loan.reload.money_account).to eq(box)
    expect(payment.reload.money_account).to eq(box)
    expect(AuditEvent.where(auditable: expense, action: "update").last.changeset).to include("money_account_id" => [ bank.id, nil ])

    expect(described_class.new(:all).apply!).to eq(1)
    expect(payment.reload.money_account).to be_nil
    expect(with_account.reload.money_account).to eq(bank)
  end

  it "runs from the rake tasks, and changes nothing without CONFIRM" do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "consolidation:list" }
    invoice = create(:invoice)
    payment = invoice.payments.create!(amount: 10, paid_on: Time.zone.today, payment_method: "cash", created_by: user)
    consolidate("abc123", items: [ "invoices:#{payment.id}" ], account: box)

    expect { Rake::Task["consolidation:list"].execute }.to output(/abc123.*1 records\n    account: Caja \(1\)/).to_stdout
    task = Rake::Task["consolidation:revert"]
    expect { task.execute(Rake::TaskArguments.new([ :request_ids ], [ "abc123" ])) }.to output(/1 records to revert.*Nothing changed/m).to_stdout
    expect(payment.reload.money_account).to eq(box)

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("CONFIRM").and_return("1")
    expect { task.execute(Rake::TaskArguments.new([ :request_ids ], [ "abc123" ])) }.to output(/Reverted 1 records/).to_stdout
    expect(payment.reload.money_account).to be_nil
  end
end
