require "rails_helper"

RSpec.describe DailyClose do
  let(:today) { Time.zone.today }

  it "adds up a day of purchases like the Excel's daily close" do
    producer = create(:producer)
    create(:purchase, producer:, gross_weight: 146, humidity_percent: 51, price_per_pound: 58)
    create(:purchase, producer:, gross_weight: 330, humidity_percent: 51, price_per_pound: 58)
    create(:purchase, gross_weight: 100, humidity_percent: 51, price_per_pound: 58)
    create(:purchase, purchased_on: today - 1)

    close = described_class.new(today)
    expect(close.purchases_count).to eq(3)
    expect(close.producers_count).to eq(2)
    expect(close.gross_weight).to eq(576)
    expect(close.net_weight).to eq(BigDecimal("71.05") + BigDecimal("160.72") + BigDecimal("48.51"))
    expect(close.total).to eq(close.purchases.sum(&:total))
  end

  it "splits the money into paid, pending and not invoiced" do
    user = create(:user)
    paid, pending, loose = create_list(:purchase, 3)
    InvoiceIssuer.new(producer: paid.producer, user:, purchase_ids: [ paid.id ], payment_status: "paid", payment_method: "cash").call
    InvoiceIssuer.new(producer: pending.producer, user:, purchase_ids: [ pending.id ], payment_status: "pending").call

    close = described_class.new(today)
    expect(close.paid_total).to eq(paid.total)
    expect(close.pending_total).to eq(pending.total)
    expect(close.uninvoiced_total).to eq(loose.total)
  end
end
