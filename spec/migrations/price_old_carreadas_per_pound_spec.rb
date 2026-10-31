require "rails_helper"
require Rails.root.join("db/migrate/20261028120000_price_old_carreadas_per_pound")

# Fernando, 2026-10-28: the carreadas still calculated by cans go by L 1 per
# net pound, and the can columns go. PostgreSQL rolls the DDL back with the
# example's transaction.
RSpec.describe PriceOldCarreadasPerPound do
  let(:migration) { described_class.new.tap { |m| m.verbose = false } }
  let(:hauler) { create(:hauler, price_per_pound: "0.3") }

  after { Purchase.reset_column_information }

  it "prices the purchases by cans at L 1 per net pound, audits each one and drops the can columns" do
    by_price = create(:purchase, coffee_state: "cherry", yield_factor: 1, gross_weight: 1_000, hauler:)
    by_cans = create(:purchase, coffee_state: "cherry", yield_factor: 1, gross_weight: 1_000, hauler:)
    without = create(:purchase)

    migration.down
    Purchase.reset_column_information
    Purchase.where(id: by_cans.id).update_all(hauler_price_per_pound: nil, hauler_commission_percent: 0.01, hauler_can_price: 16, hauler_cans: 60.24, hauler_commission: 0.01)

    expect { migration.up }.to change { AuditEvent.where(auditable: by_cans, action: "update").count }.by(1)
    Purchase.reset_column_information

    net = by_cans.reload.net_weight
    expect(by_cans).to have_attributes(hauler_price_per_pound: 1, hauler_commission: (net * 1).round(2))
    expect(by_price.reload).to have_attributes(hauler_price_per_pound: BigDecimal("0.3"), hauler_commission: (net * BigDecimal("0.3")).round(2))
    expect(without.reload).to have_attributes(hauler_price_per_pound: nil, hauler_commission: nil)
    expect(Purchase.column_names).not_to include("hauler_cans", "hauler_can_price", "hauler_commission_percent")

    event = AuditEvent.where(auditable: by_cans).last
    expect(event).to have_attributes(user_id: nil, auditable_label: by_cans.producer.full_name)
    expect(event.changeset).to include("hauler_price_per_pound" => [ nil, "1.0" ], "hauler_commission" => [ "0.01", format("%.2f", net * 1) ],
                                       "hauler_cans" => [ "60.24", nil ])
  end
end
