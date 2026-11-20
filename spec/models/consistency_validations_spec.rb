require "rails_helper"

# Everything has to match (Fernando, 2026-11-18): a lot only carries coffee
# that was in the warehouse when it left (a purchase of November went on a
# shipment of September), a buyer's weight note goes on one shipment, a sale
# comes after the buyer weighed its shipments, a process never weighs more
# than what went in, and nothing is dated in the future.
RSpec.describe "Consistency validations", :all_records do
  let(:admin) { create(:user, :admin) }
  let(:producer) { create(:producer) }

  def invoice_for(purchase)
    InvoiceIssuer.new(producer: purchase.producer, user: admin, purchase_ids: [ purchase.id ], payment_status: "pending").call.invoice
  end

  describe "lots and dates" do
    let(:departed_at) { 3.days.ago }
    let(:shipment) { create(:shipment, departed_at:) }
    let(:early) { create(:purchase, producer:, purchased_at: 5.days.ago) }
    let(:late) { create(:purchase, producer:, purchased_at: 1.day.ago) }

    it "does not put on a shipment a lot with a purchase made after it left" do
      batch = create(:coffee_batch)
      batch.batch_invoices.create!(invoice: invoice_for(late), percent: 100, created_by: admin)

      expect(batch.update(shipment:)).to be(false)
      expect(batch.errors.full_messages.join).to include("después de que salió la remisión #{shipment.display_number}")
      expect(batch.reload.shipment).to be_nil
    end

    it "lets a lot with coffee bought before the departure go on it" do
      batch = create(:coffee_batch)
      batch.batch_invoices.create!(invoice: invoice_for(early), percent: 100, created_by: admin)

      expect(batch.update(shipment:)).to be(true)
    end

    it "does not add to a lot that already left an invoice bought after it left" do
      batch = create(:coffee_batch)
      batch.batch_invoices.create!(invoice: invoice_for(early), percent: 100, created_by: admin)
      batch.update!(shipment:)

      share = batch.batch_invoices.build(invoice: invoice_for(late), percent: 100, created_by: admin)
      expect(share).not_to be_valid
      expect(share.errors.full_messages.join).to include("un lote solo lleva café que ya estaba en la bodega")
    end

    it "does not move the departure before the coffee of its lots came in, nor a purchase after its lot left" do
      batch = create(:coffee_batch)
      batch.batch_invoices.create!(invoice: invoice_for(early), percent: 100, created_by: admin)
      batch.update!(shipment:)

      expect(shipment.reload.update(departed_at: 6.days.ago)).to be(false)
      expect(shipment.errors.full_messages.join).to include(batch.label)

      # An invoiced purchase only moves in a data-maintenance task (2026-11-18).
      Current.set(maintenance: true) do
        expect(early.reload.update(purchased_at: 2.days.ago)).to be(false)
        expect(early.errors[:purchased_at].join).to include("después de que su café salió con el #{batch.label}")
        expect(early.reload.update(purchased_at: 4.days.ago)).to be(true)
      end
    end

    it "checks the lots chosen in the shipment form against its departure" do
      batch = create(:coffee_batch)
      batch.batch_invoices.create!(invoice: invoice_for(late), percent: 100, created_by: admin)

      new_shipment = build(:shipment, departed_at:)
      new_shipment.batch_ids = [ batch.id ]
      expect(new_shipment).not_to be_valid
      expect(new_shipment.errors.full_messages.join).to include(batch.label)
    end

    it "does not take into a lot that left a process finished after it left" do
      conversion = create(:coffee_conversion, :finished, weighed_at: 2.days.ago, finished_at: 1.day.ago)
      batch = create(:coffee_batch)
      batch.batch_invoices.create!(invoice: invoice_for(early), percent: 100, created_by: admin)
      batch.update!(shipment:)

      share = batch.batch_conversions.build(coffee_conversion: conversion, percent: 100, created_by: admin)
      expect(share).not_to be_valid
      expect(share.errors.full_messages.join).to include("después de que salió la remisión")
    end
  end

  describe "processes" do
    it "never come out heavier than what went in" do
      conversion = create(:coffee_conversion, weighed_at: 2.hours.ago, input_gross_weight: 1_000)
      conversion.assign_attributes(finished_at: 1.hour.ago, output_gross_weight: 1_001, output_sacks: 6, output_humidity_percent: 51, finishing: true)

      expect(conversion).not_to be_valid
      expect(conversion.errors[:output_gross_weight].join).to include("no puede pesar más que lo que entró (1,000.00 lb brutas)")

      conversion.output_gross_weight = 1_000
      expect(conversion).to be_valid
    end
  end

  describe "weight notes" do
    let(:buyer) { create(:buyer) }

    it "go on one shipment per buyer, without spaces, case or leading zeros" do
      first = create(:shipment, :received, buyer:, weight_note_number: "073")
      other = build(:shipment, :received, buyer:, weight_note_number: " 73 ")

      expect(other).not_to be_valid
      expect(other.errors[:weight_note_number].join).to include("ya está en la remisión #{first.display_number}")
      expect(build(:shipment, :received, buyer: create(:buyer), weight_note_number: "73")).to be_valid
    end
  end

  describe "sales" do
    let(:buyer) { create(:buyer) }
    let(:shipment) { create(:shipment, :received, buyer:, departed_at: 4.days.ago, received_on: 2.days.ago.to_date) }

    it "come after the buyer weighed their shipments" do
      sale = SaleIssuer.new(buyer:, shipment_ids: [ shipment.id ], user: admin,
                            sale: { sold_on: 3.days.ago.to_date, price_unit: "quintal", unit_price: 5_000, quintal_pounds: 120 }).call.sale
      expect(sale).not_to be_persisted
      expect(sale.errors[:sold_on].join).to include("antes de que el comprador pesara la remisión #{shipment.display_number}")

      sale = SaleIssuer.new(buyer:, shipment_ids: [ shipment.id ], user: admin,
                            sale: { sold_on: 2.days.ago.to_date, price_unit: "quintal", unit_price: 5_000, quintal_pounds: 120 }).call.sale
      expect(sale).to be_persisted
      expect(sale.update(sold_on: 3.days.ago.to_date)).to be(false)
      expect(shipment.reload.update(received_on: 1.day.ago.to_date)).to be(false)
      expect(shipment.errors[:received_on].join).to include("después de la venta #{sale.display_number}")
    end
  end

  describe "future dates" do
    it "are refused in purchases, shipments, payments and money" do
      expect(build(:purchase, producer:, purchased_at: 1.day.from_now)).not_to be_valid
      expect(build(:shipment, departed_at: 1.day.from_now).tap(&:valid?).errors[:departed_at].join).to include("no puede ser una fecha futura")
      expect(build(:expense, spent_on: Date.tomorrow).tap(&:valid?).errors[:spent_on]).to be_present
      expect(build(:purchase, producer:, purchased_at: Time.current)).to be_valid
    end

    it "do not block editing something saved before with a later date" do
      purchase = create(:purchase, producer:)
      purchase.update_column(:purchased_at, 2.days.from_now)

      expect(purchase.reload.update(observations: "Revisada")).to be(true)
    end
  end
end
