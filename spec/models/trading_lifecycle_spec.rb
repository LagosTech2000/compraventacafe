require "rails_helper"

RSpec.describe TradingLifecycle do
  it "follows register → invoice → pay" do
    purchase = create(:purchase)
    lifecycle = described_class.for_purchase(purchase)
    expect(lifecycle.stage).to eq("registered")
    expect(lifecycle.next_stage).to eq("invoiced")
    expect(TradingLifecycle::STAGES.map { |s| lifecycle.status(s) }).to eq(%i[done next upcoming])

    invoice = InvoiceIssuer.new(producer: purchase.producer, user: create(:user), purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
    expect(described_class.for_purchase(purchase.reload).stage).to eq("invoiced")
    expect(described_class.for_invoice(invoice).status("paid")).to eq(:next)

    invoice.mark_paid(method: "cash", on: Time.zone.today)
    lifecycle = described_class.for_purchase(purchase.reload)
    expect(lifecycle).to be_complete
    expect(TradingLifecycle::STAGES.map { |s| lifecycle.status(s) }).to eq(%i[done done done])
  end

  it "rejects unknown stages" do
    expect { described_class.new("retained") }.to raise_error(ArgumentError)
  end
end
