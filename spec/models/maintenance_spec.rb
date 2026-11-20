require "rails_helper"

# Data maintenance tasks (Fernando, 2026-11-15): checks that only read and
# say what does not add up, and tasks that fill in what is missing, with a
# preview, all or nothing, audited and undone.
RSpec.describe Maintenance do
  let(:admin) { create(:user, :admin) }

  def run(task, apply: false, **params) = Maintenance::Runner.run(task, params:, apply:, user: admin)
  def lines(run) = run.section_list.flat_map(&:lines)

  def invoice_for(producer, gross:, at: 2.days.ago)
    purchase = create(:purchase, producer:, gross_weight: gross, purchased_at: at)
    InvoiceIssuer.new(producer:, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
  end

  it "lists the same tasks as the rake file" do
    rake = File.read(Rails.root.join("lib/tasks/maintenance.rake")).scan(/^  "([a-z_]+:[a-z_]+)" =>/).flatten
    expect(rake).to eq(described_class.tasks.map(&:key))
    described_class.tasks.each do |task|
      %i[title what after risk].each { expect(task.text(it)).to be_present }
    end
  end

  it "keeps a failed run with its error, changing nothing" do
    allow_any_instance_of(Maintenance::Expenses).to receive(:sections).and_raise(ArgumentError, "boom")
    result = run(Maintenance::Expenses)
    expect(result).to have_attributes(status: "failed", error: "ArgumentError: boom", mode: "preview", user: admin)
  end

  describe "integrity:inventory" do
    it "says the stock, the kárdex and the lots match, and what is below zero" do
      create(:purchase, gross_weight: 1_000)
      result = run(Maintenance::Inventory)
      expect(result.status).to eq("ok")
      expect(lines(result).first).to match(/Pergamino húmedo: inventario 486.57 · kárdex 486.57 · lotes 486.57 lb netas\. Cuadra\./)

      create(:shipment, origin_gross_weight: 2_000)
      expect(lines(run(Maintenance::Inventory)).first).to include("En negativo")
    end
  end

  describe "integrity:shipments" do
    it "lists what each shipment is missing" do
      shipment = create(:shipment)
      result = run(Maintenance::Shipments)
      expect(result.status).to eq("bad")
      expect(lines(result)).to include("Remisión #{shipment.display_number} · #{I18n.l(shipment.departed_at.to_date)} · Pergamino húmedo: " \
                                       "sin lotes (sin merma ni costo), sin báscula del comprador y sin gastos ni precio del viaje.")
    end

    it "finds a lot with coffee that came in after its shipment left and a weight note on two shipments (Fernando, 2026-11-18)" do
      shipment = create(:shipment, :received, departed_at: 3.days.ago, weight_note_number: "73")
      twin = create(:shipment, :received, buyer: shipment.buyer)
      twin.update_column(:weight_note_number, "073")
      batch = create(:coffee_batch)
      batch.batch_invoices.create!(invoice: invoice_for(create(:producer), gross: 300, at: 1.day.ago), percent: 100, created_by: admin)
      batch.update_column(:shipment_id, shipment.id)

      found = lines(run(Maintenance::Shipments))
      expect(found).to include(a_string_including("Remisión #{shipment.display_number}", "un lote lleva café que entró después de que salió",
                                                  "su nota de peso está también en otra salida del mismo comprador"))
      expect(found).to include(a_string_including("Remisión #{twin.display_number}", "su nota de peso está también"))
    end
  end

  describe "integrity:shipment_expense_candidates" do
    it "suggests expenses without a shipment near its date, of the categories chosen" do
      shipment = create(:shipment, departed_at: Time.current)
      fuel = create(:finance_category, name: "Combustible", kind: "expense")
      diesel = create(:finance_category, name: "Diésel", kind: "expense", parent: fuel)
      near = create(:expense, category: diesel, spent_on: Time.zone.today - 1, amount: 900)
      create(:expense, spent_on: Time.zone.today - 10)
      create(:expense, category: create(:finance_category, kind: "expense"), spent_on: Time.zone.today)

      result = run(Maintenance::ShipmentExpenseCandidates, days: "2", category_ids: [ fuel.id.to_s ])
      expect(lines(result)).to include(a_string_including("Remisión #{shipment.display_number}", "##{near.id}", "Combustible › Diésel", "L 900.00"))
      expect(lines(result).grep(/Remisión/).sole.scan(/#\d+/)).to eq([ "##{near.id}" ])
    end
  end

  describe "integrity:money" do
    it "checks every balance against the ledger and warns of a zero opening balance" do
      account = create(:money_account, name: "Caja", opening_balance: 0)
      create(:expense, money_account: account, amount: 300)
      result = run(Maintenance::Money)
      expect(result.status).to eq("warn")
      expect(lines(result)).to include(a_string_including("Caja: saldo -L 300.00. Cuadra con Movimientos.", "Su saldo inicial es L 0"))
    end
  end

  describe "integrity:cash_counts" do
    it "says which cash count no longer matches the system" do
      account = create(:money_account, name: "Caja", opening_balance: 1_000)
      count = create(:cash_count, money_account: account)
      expect(run(Maintenance::CashCounts).status).to eq("ok")

      create(:expense, money_account: account, amount: 200, spent_on: count.counted_on - 1)
      result = run(Maintenance::CashCounts)
      expect(result.status).to eq("bad")
      expect(lines(result).sole).to include("Arqueo ##{count.id}", "decía L 1,000.00 y hoy dice L 800.00")
    end
  end

  describe "integrity:expenses" do
    it "lists the ones without receipt, possible twins and future ones, removing nothing" do
      category = create(:finance_category, kind: "expense")
      twin = create(:expense, category:, amount: 250, payee: "Gasolinera")
      create(:expense, category:, amount: 250, payee: "Gasolinera")
      create(:expense).update_column(:spent_on, Time.zone.today + 3) # saved before dates in the future were refused

      result = run(Maintenance::Expenses)
      expect(result.status).to eq("bad")
      expect(lines(result)).to include("3 de 3 sin foto ni PDF del comprobante. Los más recientes:", a_string_starting_with("##{twin.id}, #"))
      expect(Expense.count).to eq(3)
    end
  end

  describe "purchases:assign_single_farm" do
    it "gives the producer's only farm, audited, and is undone" do
      producer = create(:producer)
      farm = create(:farm, producer:)
      purchase = create(:purchase, producer:)
      other = create(:purchase, producer: create(:producer).tap { |many| create_list(:farm, 2, producer: many) })

      preview = run(Maintenance::SingleFarm)
      expect(lines(preview)).to include("1 compras se completarían (de 2 sin finca).")
      expect(purchase.reload.farm).to be_nil

      applied = run(Maintenance::SingleFarm, apply: true)
      expect(applied).to have_attributes(mode: "apply", status: "ok", changes_made: { "purchases" => [ [ purchase.id, farm.id ] ] })
      expect(purchase.reload.farm).to eq(farm)
      expect(other.reload.farm).to be_nil
      expect(AuditEvent.where(auditable: purchase, action: "update").last.changeset).to include("farm_id" => [ nil, farm.id ])

      revert = Maintenance::Runner.revert(applied, user: admin)
      expect(revert).to have_attributes(mode: "revert", reverted_run: applied)
      expect(purchase.reload.farm).to be_nil
      expect(applied.reload).to be_reverted
      expect(applied).not_to be_revertible
    end
  end

  describe "batches:backfill" do
    it "fills a lot for a past shipment with the oldest invoices up to its local scale, and is undone" do
      producer = create(:producer)
      older = invoice_for(producer, gross: 1_000, at: 3.days.ago)
      newer = invoice_for(producer, gross: 1_000, at: 2.days.ago)
      # Yesterday, so «later» is never in the future, whatever the hour.
      later = invoice_for(producer, gross: 1_000, at: 1.day.ago.beginning_of_day + 2.hours)
      shipment = create(:shipment, departed_at: 1.day.ago.beginning_of_day + 1.hour, origin_gross_weight: 1_500)

      preview = run(Maintenance::BatchesBackfill)
      expect(lines(preview)).to include("Se armaría 1 lote, de 1 salidas sin lote con báscula local.",
                                        a_string_starting_with("Factura #{older.display_number}: 100 %"),
                                        a_string_starting_with("Factura #{newer.display_number}: 50 %"))
      expect(CoffeeBatch.count).to eq(0)

      applied = run(Maintenance::BatchesBackfill, apply: true)
      batch = shipment.reload.coffee_batches.sole
      expect(batch.batch_invoices.map { [ it.invoice, it.percent ] }).to eq([ [ older, 100 ], [ newer, 50 ] ])
      expect(batch.gross_weight).to eq(1_500)
      expect(batch.invoices).not_to include(later)

      Maintenance::Runner.revert(applied, user: admin)
      expect(shipment.reload.coffee_batches).to be_empty
      expect(CoffeeBatchInvoice.count).to eq(0)
    end

    it "takes finished processes too, and leaves without a lot a shipment it cannot fill whole (Fernando, 2026-11-16)" do
      producer = create(:producer)
      invoice = invoice_for(producer, gross: 600, at: 3.days.ago)
      conversion = create(:coffee_conversion, :finished, from_state: "cherry", weighed_at: 3.days.ago)
      conversion.update_columns(finished_at: 2.days.ago, output_gross_weight: 400, output_net_weight: 196)
      filled = create(:shipment, departed_at: 1.day.ago, origin_gross_weight: 900)
      short = create(:shipment, departed_at: Time.current, origin_gross_weight: 500)

      preview = run(Maintenance::BatchesBackfill)
      expect(lines(preview)).to include("1 salida no se puede llenar completa y se queda sin lote: #{short.display_number}.",
                                        a_string_starting_with("Factura #{invoice.display_number}: 100 %"),
                                        a_string_starting_with("Proceso #{conversion.audit_label}: 75 %"))

      run(Maintenance::BatchesBackfill, apply: true)
      batch = filled.reload.coffee_batches.sole
      expect(batch.batch_conversions.sole).to have_attributes(coffee_conversion: conversion, percent: 75, gross_weight: 300)
      expect(batch.gross_weight).to eq(900)
      expect(short.reload.coffee_batches).to be_empty
    end
  end

  describe "integrity:check" do
    it "runs every check and says when an invoice's status does not follow its payments" do
      invoice = create(:invoice)
      invoice.update_column(:payment_status, "paid")
      result = run(Maintenance::IntegrityCheck)
      expect(result.section_list.first.title).to eq("Resumen")
      expect(lines(result)).to include("Factura #{invoice.display_number}: dice «Cancelada» y por sus abonos debería decir «Pendiente de pago».")
      expect(result.section_list.map(&:title)).to include("Cuadre del dinero · Cuentas", "Salidas incompletas · Resumen")
    end
  end

  describe "farms:plots_from_lots" do
    it "turns each producer's «Lote» farms into plots of a farm named by its place, with its varieties, and is undone" do
      parainema = CoffeeVariety.create!(name: "Parainema")
      ihcafe = CoffeeVariety.create!(name: "IHCAFE 90")
      producer = create(:producer)
      first = create(:farm, producer:, name: "Lote 1", address_line: "Las Labranzas", area_value: 2, area_unit: "manzana", observations: "Variedad Parainema y 90")
      second = create(:farm, producer:, name: "lote 2", area_value: 1, area_unit: "manzana", observations: "variedad parainema")
      bought = create(:purchase, producer:, farm: second)
      create(:farm, producer: create(:producer), name: "El Paraíso")

      expect(lines(run(Maintenance::PlotsFromLots))).to include(a_string_including("finca «Las Labranzas» (de su dirección)", "Lote 1 2 manzanas (IHCAFE 90, Parainema)"))

      applied = run(Maintenance::PlotsFromLots, apply: true)
      expect(applied.status).to eq("ok")
      expect(first.reload).to have_attributes(name: "Las Labranzas", area_value: 3, variety_ids: [ parainema.id, ihcafe.id ].sort)
      expect(first.plots.map { [ it.name, it.area_value, it.variety_names ] }).to eq([ [ "Lote 1", 2, [ "IHCAFE 90", "Parainema" ] ], [ "lote 2", 1, [ "Parainema" ] ] ])
      expect(second.reload).not_to be_active
      expect(bought.reload).to have_attributes(farm: first, farm_plot: first.plots.find_by(name: "lote 2"))

      Maintenance::Runner.revert(applied, user: admin)
      expect(first.reload).to have_attributes(name: "Lote 1", area_value: 2, variety_ids: [])
      expect(second.reload).to be_active
      expect(bought.reload).to have_attributes(farm: second, farm_plot: nil)
      expect(FarmPlot.count).to eq(0)
    end
  end

  describe "integrity:sales and sales:recalculate" do
    it "finds a sale that does not match its shipments, recalculates it and is undone" do
      sale = create(:sale, user: admin)
      line = sale.lines.sole
      expect(run(Maintenance::Sales).status).to eq("ok")

      line.update_columns(net_weight: line.net_weight + 50, amount: line.amount + 100)
      sale.update_columns(net_weight: sale.net_weight + 50, total: sale.total + 100)
      expect(lines(run(Maintenance::Sales))).to include(a_string_starting_with("Venta #{sale.display_number}: la remisión"))

      applied = run(Maintenance::SalesRecalculate, apply: true)
      expect(sale.reload.net_weight).to eq(sale.shipments.sole.destination_net_weight)
      expect(run(Maintenance::Sales).status).to eq("ok")

      Maintenance::Runner.revert(applied, user: admin)
      expect(sale.reload.net_weight).to eq(sale.shipments.sole.destination_net_weight + 50)
    end

    it "lists a sale dated before the buyer weighed its shipment, without recalculating it (Fernando, 2026-11-18)" do
      sale = create(:sale, user: admin)
      sale.update_column(:sold_on, sale.shipments.sole.received_on - 1)

      expect(lines(run(Maintenance::Sales))).to include("Venta #{sale.display_number}: tiene fecha antes de que el comprador pesara la remisión #{sale.shipments.sole.display_number}.")
      expect(Maintenance::Sales.out_of_step).to be_empty
    end
  end
end
