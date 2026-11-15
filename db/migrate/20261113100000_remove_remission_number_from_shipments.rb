# The remission's number is the shipment's own number (Fernando, 2026-11-13:
# «como número de remisión pon el número de salida»). The number typed by
# hand goes away; any one written is kept in the observations.
class RemoveRemissionNumberFromShipments < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE shipments
         SET observations = concat_ws(E'\\n', NULLIF(observations, ''), 'Remisión escrita: ' || remission_number)
       WHERE remission_number IS NOT NULL
    SQL
    remove_column :shipments, :remission_number
  end

  def down
    add_column :shipments, :remission_number, :string
  end
end
