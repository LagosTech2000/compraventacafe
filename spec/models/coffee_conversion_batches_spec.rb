require "rails_helper"

# What goes to be processed is taken from invoices, through lots (Fernando,
# 2026-11-16): its pounds are its lots', it takes their coffee from the
# stock, the lot stays locked, and voiding the process lets it go.
RSpec.describe CoffeeConversion do
  let(:admin) { create(:user, :admin) }
  let(:purchase) { create(:purchase, gross_weight: 2_000) }
  let(:invoice) { InvoiceIssuer.new(producer: purchase.producer, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice }
  let(:batch) do
    create(:coffee_batch, warehouse: purchase.warehouse, coffee_state: "wet_parchment", gross_limit: 5_000).tap do
      it.batch_invoices.create!(invoice:, percent: 50, created_by: admin)
    end
  end

  def process!(**attributes)
    described_class.create!(from_state: "wet_parchment", warehouse: purchase.warehouse, processing_site: create(:processing_site),
                            weighed_at: Time.current, estimated_yield_percent: 50, created_by: admin, **attributes)
  end

  it "takes its pounds and its coffee from its lots, and lets them go when voided" do
    conversion = process!(batch_ids: [ batch.id ])
    expect(conversion).to have_attributes(input_gross_weight: 1_000, input_net_weight: (purchase.net_weight / 2).round(2))
    expect(batch.reload.processing).to eq(conversion)
    expect(CoffeeLots.new.portions_for(conversion).map { it.lot.source }).to eq([ purchase ])

    # The invoice shares one 100 % with lots and processes; the lot keeps its invoices.
    other = create(:coffee_batch, warehouse: purchase.warehouse, coffee_state: "wet_parchment", gross_limit: 5_000)
    expect(other.batch_invoices.create(invoice:, percent: 60, created_by: admin).errors[:percent]).to be_present
    expect(batch.batch_invoices.first.update(percent: 40)).to be(false)
    expect(CoffeeBatchPolicy.new(admin, batch).destroy?).to be(false)

    expect { process!(batch_ids: [ batch.id ]) }.to raise_error(ActiveRecord::RecordInvalid, /ya está en una salida o en otro proceso/)
    expect { process!(batch_ids: []) }.to raise_error(ActiveRecord::RecordInvalid, /Marca al menos un lote/)

    conversion.void!(admin)
    expect(batch.reload.processing).to be_nil
  end
end
