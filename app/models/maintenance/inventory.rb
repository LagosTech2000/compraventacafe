module Maintenance
  # integrity:inventory — of each coffee state, in each warehouse: the stock
  # (CoffeeStock), the kárdex's last balance (StockLedger) and what is left
  # in the lots (CoffeeLots) must be the same net pounds. Also says what is
  # below zero and the cherry waiting too long. Reads only.
  class Inventory < Task
    self.key = "integrity:inventory"
    self.tier = :check
    self.area = :sales

    def sections
      lots = CoffeeLots.new
      today = Time.zone.today
      warehouses.map do |warehouse|
        lines = []
        worst = "ok"
        Purchase::COFFEE_STATES.each do |state|
          stock = CoffeeStock.new(today, warehouse:).row(state).stock.to_d
          ledger = StockLedger.new(from: nil, to: today, coffee_state: state, warehouse:).closing.to_d
          left = lots.lots(coffee_state: state, warehouse_id: warehouse.id).sum(0.to_d, &:net)
          next if [ stock, ledger, left ].all?(&:zero?)

          name = Purchase.human_attribute_name("coffee_state/#{state}")
          figures = t(:figures, state: name, stock: pounds(stock), ledger: pounds(ledger), lots: pounds(left))
          if stock.negative?
            worst = Maintenance.worst([ worst, "bad" ])
            lines << t(:negative, figures:)
          elsif !same?(stock, ledger) || !same?(stock, left, 0.05)
            worst = Maintenance.worst([ worst, "bad" ])
            lines << t(:differs, figures:)
          else
            lines << t(:matches, figures:)
          end
        end
        lines << t(:empty) if lines.empty?
        section(t(:warehouse, name: warehouse.name), worst, lines)
      end + [ cherry_section(lots) ]
    end

    private
      def warehouses = Warehouse.order(:id).select { it.active? || Purchase.where(warehouse_id: it.id).exists? }

      def cherry_section(lots)
        alert = CherryAlert.new(lots:)
        return section(t(:cherry_title), "ok", [ t(:cherry_none) ]) unless alert.any?

        section(t(:cherry_title), alert.critical.any? ? "bad" : "warn",
                [ t(:cherry_waiting, count: alert.items.size, critical: alert.critical.size, pounds: pounds(alert.net)) ])
      end
  end
end
