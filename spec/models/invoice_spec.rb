require "rails_helper"

RSpec.describe Invoice do
  let(:user) { create(:user) }
  let(:producer) { create(:producer) }

  def issue(purchases, **options)
    InvoiceIssuer.new(producer:, user:, purchase_ids: purchases.map(&:id), payment_status: "pending", **options).call
  end

  it "numbers invoices correlatively and shows four digits" do
    first = issue([ create(:purchase, producer:) ]).invoice
    second = issue([ create(:purchase, producer:) ]).invoice
    expect(second.number).to eq(first.number + 1)
    expect(first.display_number).to eq(format("%04d", first.number))
  end

  it "groups several purchases of the producer and sums them" do
    purchases = create_list(:purchase, 3, producer:)
    invoice = issue(purchases).invoice
    expect(invoice.purchases).to match_array(purchases)
    expect(invoice.total).to eq(purchases.sum(&:total))
  end

  it "requires at least one purchase" do
    result = issue([])
    expect(result).not_to be_success
    expect(result.invoice.errors[:purchases]).to be_present
  end

  it "refuses purchases of another producer" do
    result = issue([ create(:purchase) ])
    expect(result).not_to be_success
  end

  it "refuses purchases that are already invoiced" do
    purchase = create(:purchase, producer:)
    issue([ purchase ])
    result = issue([ purchase ])
    expect(result).not_to be_success
    expect(result.invoice.errors[:purchases].first).to include("ya no están disponibles")
  end

  it "requires method and date when created as paid, defaulting the date to today" do
    expect(issue([ create(:purchase, producer:) ], payment_status: "paid")).not_to be_success
    invoice = issue([ create(:purchase, producer:) ], payment_status: "paid", payment_method: "cash").invoice
    expect(invoice).to be_persisted
    expect(invoice.paid_on).to eq(Time.zone.today)
  end

  it "can be marked as paid later" do
    invoice = issue([ create(:purchase, producer:) ]).invoice
    expect(invoice.mark_paid(method: "transfer", on: Date.new(2026, 9, 27))).to be(true)
    expect(invoice.reload).to have_attributes(payment_status: "paid", payment_method: "transfer", paid_on: Date.new(2026, 9, 27))
  end

  it "only accepts the known payment methods" do
    invoice = issue([ create(:purchase, producer:) ]).invoice
    expect(invoice.mark_paid(method: "bitcoin", on: Time.zone.today)).to be(false)
  end
end
