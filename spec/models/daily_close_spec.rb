require "rails_helper"

RSpec.describe DailyClose do
  let(:today) { Time.zone.today }

  it "adds up a day of purchases like the Excel's daily close" do
    producer = create(:producer)
    create(:purchase, producer:, gross_weight: 146, humidity_percent: 51, price_per_pound: 58)
    create(:purchase, producer:, gross_weight: 330, humidity_percent: 51, price_per_pound: 58)
    create(:purchase, gross_weight: 100, humidity_percent: 51, price_per_pound: 58)
    create(:purchase, purchased_at: today - 1)

    close = described_class.new(today)
    expect(close.purchases_count).to eq(3)
    expect(close.producers_count).to eq(2)
    expect(close.gross_weight).to eq(576)
    expect(close.net_weight).to eq(BigDecimal("71.05") + BigDecimal("160.72") + BigDecimal("48.51"))
    expect(close.total).to eq(close.purchases.sum(&:total))
  end

  it "splits the money into paid, paid in part, pending and not invoiced, with what partial invoices were paid and owe" do
    user = create(:user)
    paid, partial, pending, loose = create_list(:purchase, 4)
    InvoiceIssuer.new(producer: paid.producer, user:, purchase_ids: [ paid.id ], payment_status: "paid", payment_method: "cash").call
    InvoiceIssuer.new(producer: partial.producer, user:, purchase_ids: [ partial.id ], payment_status: "partial",
                      payment_method: "cash", amount: "1000").call
    InvoiceIssuer.new(producer: pending.producer, user:, purchase_ids: [ pending.id ], payment_status: "pending").call

    close = described_class.new(today)
    expect(close.paid_total).to eq(paid.total)
    expect(close.partial_total).to eq(partial.total)
    expect(close.pending_total).to eq(pending.total)
    expect(close.uninvoiced_total).to eq(loose.total)
    expect(close.payment_states.map { |row| [ row.state, row.count ] }).to eq([ [ "paid", 1 ], [ "partial", 1 ], [ "pending", 1 ], [ "uninvoiced", 1 ] ])
    expect(close.partial_paid).to eq(1000)
    expect(close.partial_balance).to eq(partial.total - 1000)
    expect(close.partial_invoices).to eq([ partial.reload.invoice ])
  end

  it "counts every state, also the empty ones" do
    create(:purchase)
    expect(described_class.new(today).payment_states.map { |row| [ row.state, row.count ] })
      .to eq([ [ "paid", 0 ], [ "partial", 0 ], [ "pending", 0 ], [ "uninvoiced", 1 ] ])
    expect(described_class.new(today).partial_paid).to eq(0)
  end

  it "takes what was paid and owed of a partial invoice whole, with loans paid with its coffee off" do
    user = create(:user)
    old = create(:purchase, purchased_at: today - 1)
    new = create(:purchase, producer: old.producer)
    InvoiceIssuer.new(producer: old.producer, user:, purchase_ids: [ old.id, new.id ], payment_status: "partial",
                      payment_method: "cash", amount: "500").call

    close = described_class.new(today)
    expect(close.partial_total).to eq(new.total)
    expect(close.partial_balance).to eq(old.total + new.total - 500)
  end

  it "lists paid purchases first, then paid in part, then pending, then not invoiced; newest first within each" do
    user = create(:user)
    loose_old, loose_new = create_list(:purchase, 2)
    pending = create(:purchase)
    partial = create(:purchase)
    InvoiceIssuer.new(producer: partial.producer, user:, purchase_ids: [ partial.id ], payment_status: "partial",
                      payment_method: "cash", amount: "100").call
    paid_old, paid_new = create_list(:purchase, 2)
    InvoiceIssuer.new(producer: pending.producer, user:, purchase_ids: [ pending.id ], payment_status: "pending").call
    [ paid_old, paid_new ].each do |purchase|
      InvoiceIssuer.new(producer: purchase.producer, user:, purchase_ids: [ purchase.id ], payment_status: "paid", payment_method: "cash").call
    end

    expect(described_class.new(today).purchases).to eq([ paid_new, paid_old, partial, pending, loose_new, loose_old ])
  end

  it "groups purchases by payment state for the printed report, skipping empty states" do
    user = create(:user)
    paid = create(:purchase)
    loose = create(:purchase)
    InvoiceIssuer.new(producer: paid.producer, user:, purchase_ids: [ paid.id ], payment_status: "paid", payment_method: "cash").call

    expect(described_class.new(today).groups).to eq([ [ "paid", [ paid ] ], [ "uninvoiced", [ loose ] ] ])
  end
end
