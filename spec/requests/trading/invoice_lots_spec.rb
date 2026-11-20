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

  # An invoice is never edited (Fernando, 2026-11-18): its lot changes from the lot.
  it "offers no lot of a sold shipment, to an administrator either" do
    purchase
    admin = create(:user, :admin)
    lot = create(:coffee_batch)
    sale_shipment = create(:shipment, :received, coffee_state: lot.coffee_state, warehouse: lot.warehouse)
    lot.update!(shipment: sale_shipment)
    SaleIssuer.new(buyer: sale_shipment.buyer, user: admin, shipment_ids: [ sale_shipment.id ],
                   sale: { price_unit: "pound", unit_price: "50", quintal_pounds: "120" }, payment_status: "pending").call
    expect(sale_shipment.reload).to be_sold
    sign_in admin

    get new_trading_invoice_path(producer_id: producer.id)
    expect(response.body).not_to include(%(value="#{lot.id}" data-state))
  end
end
