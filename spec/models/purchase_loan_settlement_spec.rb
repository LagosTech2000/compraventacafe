require "rails_helper"

RSpec.describe PurchaseLoanSettlement do
  let(:user) { create(:user) }
  let(:producer) { create(:producer) }
  # 146 lb at 51 % and L 58: L 4,120.90.
  let(:purchase) { create(:purchase, producer:) }
  let(:today) { Time.zone.today }
  let!(:first_due) { create(:loan, person: producer.person, cash_amount: 1_000, monthly_interest_rate: 0, disbursed_on: today - 30, due_on: today + 5) }
  let!(:later_due) { create(:loan, person: producer.person, cash_amount: 5_000, monthly_interest_rate: 0, disbursed_on: today - 30, due_on: today + 60) }

  def settle(amounts, **options)
    described_class.new(purchase:, user:, amounts:, **options)
  end

  it "lists the person's open loans, due first, with what they owe" do
    settlement = settle({})
    expect(settlement.open_loans).to eq([ first_due, later_due ])
    expect(settlement.total_owed).to eq(6_000)
  end

  it "pays several loans with the purchase, settling the ones it covers" do
    settlement = settle({ first_due.id => "1000", later_due.id => "2,000.50" })
    expect(settlement.save).to be(true)
    expect(first_due.reload).to be_paid_off
    expect(later_due.balance.total_owed).to eq(BigDecimal("2999.50"))
    expect(LoanPayment.where(purchase:).pluck(:payment_method).uniq).to eq([ "coffee" ])
    expect(purchase.reload.amount_to_pay).to eq(BigDecimal("1120.40"))
  end

  it "never takes more than the purchase has, counting earlier payments" do
    settle({ later_due.id => "4000" }).save
    settlement = settle({ first_due.id => "200" })
    expect(settlement.save).to be(false)
    expect(settlement.errors.full_messages.first).to include("L 120.90")
  end

  it "saves all payments or none" do
    small = create(:loan, person: producer.person, cash_amount: 100, monthly_interest_rate: 0, disbursed_on: today - 30, due_on: today + 90)
    settlement = settle({ first_due.id => "500", small.id => "300" })
    expect(settlement.save).to be(false)
    expect(LoanPayment.count).to eq(0)
    expect(settlement.errors.full_messages.join).to include("Préstamo #{small.id}: Monto (L) es mayor que lo que se debe")
  end

  it "asks for at least one amount and refuses negative ones, in Spanish" do
    expect(settle({ first_due.id => "" }).tap(&:save).errors.full_messages).to eq([ "Escribe cuánto abonar al menos a un préstamo." ])
    expect(settle({ first_due.id => "-5" }).tap(&:save).errors.full_messages).to include("Los montos no pueden ser negativos.")
  end

  it "refuses loans of somebody else" do
    other = create(:loan)
    expect(settle({ other.id => "10" }).save).to be(false)
  end

  it "does not use a voided purchase or one whose invoice was already paid" do
    invoice = InvoiceIssuer.new(producer:, user:, purchase_ids: [ purchase.id ], payment_status: "paid", payment_method: "cash", paid_on: today).call.invoice
    expect(invoice).to be_paid
    expect(settle({ first_due.id => "10" }).save).to be(false)
    expect(purchase.reload.accepts_loan_payments?).to be(false)
  end

  it "freezes the purchase once it paid a loan, and the invoice takes the payment off" do
    settle({ first_due.id => "1000" }).save
    expect(PurchasePolicy.new(create(:user, :admin), purchase.reload)).to forbid_actions(%i[update destroy void])

    invoice = InvoiceIssuer.new(producer:, user:, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
    expect(invoice.reload).to have_attributes(total: BigDecimal("4120.90"), loan_payments_total: 1_000, amount_to_pay: BigDecimal("3120.90"))
  end

  it "does not register a coffee payment by hand" do
    payment = build(:loan_payment, loan: first_due, payment_method: "coffee")
    expect(payment).not_to be_valid
    expect(payment.errors.full_messages).to include("Forma de pago «Con café» solo se registra desde una compra")
  end
end
