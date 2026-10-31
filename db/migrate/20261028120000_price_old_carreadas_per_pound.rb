# Every carreada goes by price per pound now (Fernando, 2026-10-28: «lo de
# comisión ya no se usará y todo será por el precio establecido por libra
# neta»). The purchases still calculated by cans (before 2026-10-24) take
# L 1 per net pound, the price Fernando set for them, and their commission
# is net pounds × 1. Each change is left in the audit as done by the system.
# Then the can columns go: nothing uses them any more.
class PriceOldCarreadasPerPound < ActiveRecord::Migration[8.1]
  PRICE = 1

  def up
    execute <<~SQL
      WITH changed AS (
        UPDATE purchases p
           SET hauler_price_per_pound = #{PRICE},
               hauler_commission = ROUND(p.net_weight * #{PRICE}, 2),
               hauler_commission_percent = NULL, hauler_can_price = NULL, hauler_cans = NULL
          FROM purchases old
         WHERE old.id = p.id
           AND p.hauler_id IS NOT NULL AND p.hauler_price_per_pound IS NULL AND p.net_weight IS NOT NULL
        RETURNING p.id, p.producer_id, old.hauler_commission AS old_commission, p.hauler_commission AS new_commission,
                  old.hauler_commission_percent, old.hauler_can_price, old.hauler_cans
      )
      INSERT INTO audit_events (action, auditable_type, auditable_id, auditable_label, changeset, details, created_at)
      SELECT 'update', 'Purchase', changed.id, people.first_names || ' ' || people.last_names,
             jsonb_build_object(
               'hauler_price_per_pound', jsonb_build_array(NULL, '#{PRICE}.0'),
               'hauler_commission', jsonb_build_array(changed.old_commission::text, changed.new_commission::text),
               'hauler_commission_percent', jsonb_build_array(changed.hauler_commission_percent::text, NULL),
               'hauler_can_price', jsonb_build_array(changed.hauler_can_price::text, NULL),
               'hauler_cans', jsonb_build_array(changed.hauler_cans::text, NULL)),
             '{}'::jsonb, NOW()
        FROM changed
        JOIN producers ON producers.id = changed.producer_id
        JOIN people ON people.id = producers.person_id
    SQL

    remove_column :purchases, :hauler_commission_percent
    remove_column :purchases, :hauler_can_price
    remove_column :purchases, :hauler_cans
  end

  # The columns come back empty: the commissions by cans are in the audit.
  def down
    add_column :purchases, :hauler_commission_percent, :decimal, precision: 5, scale: 2
    add_column :purchases, :hauler_can_price, :decimal, precision: 12, scale: 2
    add_column :purchases, :hauler_cans, :decimal, precision: 12, scale: 2
  end
end
