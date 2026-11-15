require "rails_helper"

# A new invoice can go in a lot from «Facturar compras», with a percent
# (Fernando, 2026-11-13): the lot's rules hold (its limit, its coffee state
# and warehouse), all of it is saved or none, and only who can add invoices
# to lots (Salidas) chooses one.
RSpec.describe "Invoicing into a lot" do
  let(:producer) { create(:producer) }
  let(:purchase) { create(:purchase, producer:, gross_weight: 1_000) }
  let(:user) do
    create(:user).tap do |u|
      create(:permission, user: u, module_key: "trading", can_read: true, can_create: true, can_update: true, can_destroy: true)
      create(:permission, user: u, module_key: "sales", submodule_key: "shipments", can_read: true, can_update: true)
    end
  end

  before { sign_in user }

  def invoice!(**extra)
    post trading_invoices_path, params: { producer_id: producer.id,
                                          invoice: { purchase_ids: [ purchase.id ], payment_status: "pending", **extra } }
  end

  it "lists the lots with room in the form and puts the invoice in the chosen one with its percent" do
    lot = create(:coffee_batch, gross_limit: 800, created_by: user)
    full = create(:coffee_batch, gross_limit: 1, created_by: user)
    other = create(:coffee_batch, gross_limit: 100, created_by: user)
    other_invoice = InvoiceIssuer.new(producer:, user:, purchase_ids: [ create(:purchase, producer:, gross_weight: 100).id ], payment_status: "pending").call.invoice
    full.batch_invoices.create!(invoice: other_invoice, percent: 1, created_by: user)

    get new_trading_invoice_path(producer_id: producer.id)
    expect(response.body).to include(lot.label, other.label)
    expect(response.body).not_to include("#{full.label} ·")

    invoice!(coffee_batch_id: lot.id, batch_percent: "50")
    invoice = Invoice.order(:id).last
    expect(response).to redirect_to(trading_invoice_path(invoice))
    expect(lot.batch_invoices.sole).to have_attributes(invoice:, percent: 50, gross_weight: 500)
  end

  it "takes 100 % when no percent comes" do
    lot = create(:coffee_batch, created_by: user)
    invoice!(coffee_batch_id: lot.id, batch_percent: "")
    expect(lot.batch_invoices.sole.percent).to eq(100)
  end

  it "saves nothing when the percent passes the lot's limit" do
    lot = create(:coffee_batch, gross_limit: 400, created_by: user)
    expect { invoice!(coffee_batch_id: lot.id, batch_percent: "50") }.not_to change(Invoice, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(lot.label)
    expect(purchase.reload.invoice).to be_nil
    expect(lot.batch_invoices).to be_empty
  end

  it "saves nothing when the lot is of another coffee state" do
    lot = create(:coffee_batch, coffee_state: "cherry", created_by: user)
    expect { invoice!(coffee_batch_id: lot.id) }.not_to change(Invoice, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "does not offer lots, nor take one, without editing Salidas" do
    trader = create(:user).tap { create(:permission, user: it, module_key: "trading", can_read: true, can_create: true, can_update: true) }
    lot = create(:coffee_batch, created_by: trader)
    sign_in trader

    get new_trading_invoice_path(producer_id: producer.id)
    expect(response.body).not_to include("invoice[coffee_batch_id]")

    expect { invoice!(coffee_batch_id: lot.id) }.not_to change(Invoice, :count)
    expect(lot.batch_invoices).to be_empty
  end

  describe "editing the invoice (an administrator)" do
    let(:admin) { create(:user, :admin) }
    let(:invoice) { InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice }

    before { sign_in admin }

    def edit!(**lot)
      patch trading_invoice_path(invoice), params: { invoice: { issued_on: invoice.issued_on, observations: "", purchase_ids: invoice.purchase_ids, **lot } }
    end

    it "shows its lot with its percent and the room counting what it took" do
      lot = create(:coffee_batch, gross_limit: 600)
      lot.batch_invoices.create!(invoice:, percent: 50, created_by: admin)

      get edit_trading_invoice_path(invoice)
      expect(response.body).to include(%(value="#{lot.id}" data-state="wet_parchment"), %(data-room="600.0"), %(value="50"))
      expect(response.body).to include(%(name="invoice[lot_was]"))
    end

    it "puts it in a lot, changes its percent, moves it and takes it out" do
      lot = create(:coffee_batch)
      other = create(:coffee_batch)

      edit!(coffee_batch_id: lot.id, batch_percent: "40", lot_was: ":")
      expect(response).to redirect_to(trading_invoice_path(invoice))
      expect(invoice.batch_invoices.sole).to have_attributes(coffee_batch: lot, percent: 40, gross_weight: 400)

      edit!(coffee_batch_id: lot.id, batch_percent: "60", lot_was: "#{lot.id}:#{40.to_d}")
      expect(invoice.batch_invoices.sole).to have_attributes(coffee_batch: lot, percent: 60, gross_weight: 600)

      edit!(coffee_batch_id: other.id, batch_percent: "60", lot_was: "#{lot.id}:#{60.to_d}")
      expect(invoice.batch_invoices.sole).to have_attributes(coffee_batch: other, percent: 60)

      edit!(coffee_batch_id: "", lot_was: "#{other.id}:#{60.to_d}")
      expect(invoice.batch_invoices).to be_empty
    end

    it "leaves the lot's pounds alone when the lot was not touched and a purchase is added" do
      lot = create(:coffee_batch)
      lot.batch_invoices.create!(invoice:, percent: 50, created_by: admin)
      extra = create(:purchase, producer:, gross_weight: 1_000)

      patch trading_invoice_path(invoice), params: { invoice: { issued_on: invoice.issued_on, purchase_ids: [ purchase.id, extra.id ],
                                                                coffee_batch_id: lot.id, batch_percent: "50", lot_was: "#{lot.id}:#{50.to_d}" } }
      expect(invoice.batch_invoices.sole).to have_attributes(percent: 25, gross_weight: 500)
    end

    it "saves nothing when the new percent passes the lot's limit" do
      lot = create(:coffee_batch, gross_limit: 500)
      lot.batch_invoices.create!(invoice:, percent: 50, created_by: admin)

      edit!(coffee_batch_id: lot.id, batch_percent: "80", lot_was: "#{lot.id}:#{50.to_d}", observations: "nuevo")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(lot.label)
      expect(invoice.reload.observations).to be_blank
      expect(invoice.batch_invoices.sole.percent).to eq(50)
    end

    it "lists the lots of an invoice split in several and changes none from here" do
      lot = create(:coffee_batch)
      other = create(:coffee_batch)
      lot.batch_invoices.create!(invoice:, percent: 40, created_by: admin)
      other.batch_invoices.create!(invoice:, percent: 60, created_by: admin)

      get edit_trading_invoice_path(invoice)
      expect(response.body).to include("repartida en #{lot.label} (40 %) y #{other.label} (60 %)")
      expect(response.body).not_to include("invoice[coffee_batch_id]")

      edit!(coffee_batch_id: "")
      expect(invoice.batch_invoices.count).to eq(2)
    end
  end
end
