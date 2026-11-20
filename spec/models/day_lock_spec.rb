require "rails_helper"

# A day closed for the business (Fernando, 2026-11-18): nothing dated that
# day or before is created, changed or deleted; what comes after on an open
# day still gets in.
RSpec.describe DayLock do
  let(:admin) { create(:user, :admin) }

  def close(day) = BusinessDayClose.create!(closed_on: day, closed_by: admin)

  it "refuses to create, change, void or delete what is dated on a closed day or before" do
    old = create(:purchase, purchased_at: 2.days.ago)
    expense = create(:expense, spent_on: 3.days.ago.to_date)
    close(1.day.ago.to_date)

    late = build(:purchase, purchased_at: 1.day.ago.change(hour: 10))
    expect(late).not_to be_valid
    expect(late.errors.full_messages.join).to include("está cerrado")
    expect(build(:purchase, purchased_at: Time.current)).to be_valid

    expect(old.update(price_per_pound: 99)).to be(false)
    expect(old.update(voided_at: Time.current)).to be(false)
    fresh = create(:purchase, purchased_at: Time.current)
    expect(fresh.update(purchased_at: 3.days.ago)).to be(false)

    expect(expense.destroy).to be(false)
    expect(Expense.exists?(expense.id)).to be(true)
  end

  it "lets in what an open day does to a closed day's records" do
    purchase = create(:purchase, purchased_at: 2.days.ago)
    shipment = create(:shipment, departed_at: 2.days.ago)
    loan = create(:loan, disbursed_on: 10.days.ago, cash_amount: 100, monthly_interest_rate: 0)
    close(1.day.ago.to_date)

    invoice = InvoiceIssuer.new(producer: purchase.producer, user: admin, purchase_ids: [ purchase.id ], payment_status: "paid", payment_method: "cash").call
    expect(invoice).to be_success
    expect(purchase.reload.invoice).to be_paid

    shipment.assign_attributes(receiving: true, received_on: Time.zone.today, destination_gross_weight: 990, destination_sacks: 6, destination_humidity_percent: 51)
    expect(shipment.save).to be(true)
    expect(shipment.reload.update(received_on: 2.days.ago.to_date)).to be(false)

    loan.payments.create!(amount: 100, paid_on: Time.zone.today, payment_method: "cash", created_by: admin)
    expect(loan.reload).to be_paid_off
  end

  it "keeps a closed day's shipment with its lots" do
    shipment = create(:shipment, departed_at: 2.days.ago)
    lot = create(:coffee_batch, batched_on: 3.days.ago.to_date)
    close(1.day.ago.to_date)
    expect(lot.update(shipment:)).to be(false)
    expect(shipment.update(batch_ids: [ lot.id ])).to be(false)
  end

  it "is skipped by a data-maintenance task" do
    purchase = create(:purchase, purchased_at: 2.days.ago)
    close(1.day.ago.to_date)
    Current.maintenance = :task
    expect(purchase.update(price_per_pound: 99)).to be(true)
  ensure
    Current.maintenance = nil
  end
end
