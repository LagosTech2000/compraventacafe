require "rails_helper"

# A lot keeps the gross and net pounds it took of an invoice (Fernando,
# 2026-11-13: «si una compra se edita su peso debería quedar como porcentaje
# no asignado a ningún lote para que no afecte las salidas»). Since
# 2026-11-18 an invoiced purchase only changes in a data-maintenance task.
RSpec.describe CoffeeBatchInvoice, :all_records do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer) }
  let(:purchase) { create(:purchase, producer:, gross_weight: 1_000) }
  let(:other_purchase) { create(:purchase, producer:, gross_weight: 500) }
  let!(:invoice) do
    InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id, other_purchase.id ], payment_status: "pending").call.invoice
  end
  let(:batch) { create(:coffee_batch, gross_limit: 5_000) }
  let!(:line) { batch.batch_invoices.create!(invoice:, percent: 100, created_by: admin) }

  it "keeps the pounds it took when a purchase grows, and leaves what it adds free for another lot" do
    gross, net, value = line.gross_weight, line.net_weight, batch.value
    expect(gross).to eq(1_500)

    Current.set(maintenance: true) { purchase.reload.update!(gross_weight: 2_000) }
    line.reload
    expect([ line.gross_weight, line.net_weight ]).to eq([ gross, net ])
    expect(line.percent).to be_within(0.001).of(60)
    expect(CoffeeBatch.find(batch.id).gross_weight).to eq(gross)
    expect(CoffeeBatch.find(batch.id).value).to be_within(0.05).of(value)

    rest = create(:coffee_batch, gross_limit: 5_000).batch_invoices.create!(invoice:, percent: 100 - line.percent, created_by: admin)
    expect(rest.gross_weight).to be <= 1_000
    expect(rest.gross_weight).to be_within(0.5).of(1_000)
  end

  it "does not let a purchase drop below what its lots took, in gross or net pounds" do
    Current.set(maintenance: true) do
      expect(purchase.reload.update(gross_weight: 900)).to be(false)
      expect(purchase.errors.full_messages.join).to include("Sus lotes tomaron de esta factura 1,500.00 lb brutas")
      expect(purchase.reload.gross_weight).to eq(1_000)

      expect(purchase.reload.update(humidity_percent: purchase.humidity_percent + 5)).to be(false)
    end
    expect(line.reload.percent).to eq(100)
  end

  it "lets a purchase drop while its invoice still holds what the lots took" do
    line.update!(percent: 50)
    expect(line.gross_weight).to eq(750)

    Current.set(maintenance: true) { purchase.reload.update!(gross_weight: 800) }
    line.reload
    expect(line.gross_weight).to eq(750)
    expect(line.percent).to be_within(0.001).of(750 * 100 / 1_300.0)
  end

  it "keeps an invoiced purchase as it was printed, outside a data-maintenance task" do
    expect(purchase.reload.update(gross_weight: 2_000)).to be(false)
    expect(purchase.errors.full_messages.join).to include("Una compra facturada no se edita")
    expect(purchase.reload.update(observations: "Revisada")).to be(true)
  end
end
