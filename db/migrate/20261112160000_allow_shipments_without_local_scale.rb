# Administrators may register a shipment without the local scale (Fernando,
# 2026-11-12): its local weights stay empty until someone completes them;
# meanwhile it takes no coffee out of the stock and has no difference
# between scales. A sale with such a shipment has no local net either.
class AllowShipmentsWithoutLocalScale < ActiveRecord::Migration[8.1]
  def change
    change_column_null :shipments, :origin_gross_weight, true
    change_column_null :shipments, :origin_sacks, true
    change_column_null :shipments, :origin_tare, true
    change_column_null :shipments, :origin_net_weight, true
    change_column_null :sale_lines, :origin_net_weight, true
    change_column_null :sales, :origin_net_weight, true
  end
end
