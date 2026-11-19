module Maintenance
  # integrity:sales — each sale against its shipments now (Fernando,
  # 2026-11-15: «para tener todo cuadrado en las ventas»): each line's
  # buyer and local net weights and amount against its shipment's scales and
  # the sale's price, and the sale's weights and total against its lines.
  # Reads only; sales:recalculate fixes them.
  class Sales < Task
    self.key = "integrity:sales"
    self.tier = :check
    self.area = :sales

    def self.out_of_step
      # A date before the arrival is not fixed by recalculating: only listed.
      ::Sale.active.includes(lines: :shipment).order(:id).select { |sale| gaps_of(sale).any? { |gap, _| gap != :before_arrival } }
    end

    # What does not match in a sale (empty when it matches).
    def self.gaps_of(sale)
      lines = sale.lines.select(&:active?)
      price = { unit_price: sale.unit_price, price_unit: sale.price_unit, quintal_pounds: sale.quintal_pounds }
      priced = sale.unit_price.to_d.positive?
      gaps = []
      lines.each do |line|
        shipment = line.shipment
        gaps << [ :line_net, shipment.display_number ] unless near?(line.net_weight, shipment.destination_net_weight)
        gaps << [ :line_origin, shipment.display_number ] unless near?(line.origin_net_weight, shipment.origin_net_weight)
        gaps << [ :before_arrival, shipment.display_number ] if shipment.received_on && sale.sold_on < shipment.received_on
        gaps << [ :line_amount, shipment.display_number ] if priced && shipment.destination_net_weight && !near?(line.amount, ::Sale.amount_for(shipment.destination_net_weight, **price))
      end
      gaps << [ :sale_net, nil ] unless near?(sale.net_weight, lines.sum { it.net_weight.to_d })
      gaps << [ :sale_total, nil ] if priced && !near?(sale.total, ::Sale.amount_for(sale.net_weight, **price))
      gaps
    end

    def self.near?(a, b) = (a.nil? && b.nil?) || (!a.nil? && !b.nil? && (a.to_d - b.to_d).abs <= 0.01)

    def sections
      sales = ::Sale.active.includes(lines: :shipment).order(:id).to_a
      lines = sales.filter_map do |sale|
        gaps = self.class.gaps_of(sale)
        next if gaps.empty?

        t(:line, number: sale.display_number, gaps: gaps.map { |gap, shipment| t("gaps.#{gap}", shipment:) }.uniq.to_sentence)
      end
      [ section(t(:title), lines.any? ? "bad" : "ok", [ t(:total, count: sales.size) ] + (lines.presence || [ t(:none) ])) ]
    end
  end
end
