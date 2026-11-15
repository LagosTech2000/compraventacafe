module Maintenance
  # integrity:shipments — each shipment that is missing something for its
  # cost, shrink and scale difference to be known: lots, the local scale,
  # the buyer's scale, its expenses, its sale or its collection. Reads only.
  class Shipments < Task
    self.key = "integrity:shipments"
    self.tier = :check
    self.area = :sales

    # What blocks a figure (bad) and what is only incomplete (warn).
    BLOCKING = %i[no_lots no_origin].freeze

    def sections
      shipments = Shipment.active.includes(:coffee_batches, :costs, :expenses, :warehouse, active_sale_line: :sale).order(:departed_at, :id).to_a
      counts = Hash.new(0)
      lines = shipments.filter_map do |shipment|
        gaps = gaps_of(shipment)
        next if gaps.empty?

        gaps.each { counts[it] += 1 }
        t(:line, number: shipment.display_number, date: day(shipment.departed_at.in_time_zone), state: shipment.human_coffee_state,
                 gaps: gaps.map { t("gaps.#{it}") }.to_sentence)
      end
      summary = [ t(:total, count: shipments.size) ] + counts.sort_by { -it.last }.map { |gap, count| t(:count, gap: t("gaps.#{gap}"), count:) }
      status = if counts.keys.intersect?(BLOCKING) then "bad"
      elsif counts.any? then "warn"
      else "ok"
      end
      [ section(t(:summary), status, summary), section(t(:list), status, lines.presence || [ t(:none) ]) ]
    end

    private
      def gaps_of(shipment)
        gaps = []
        gaps << :no_lots if shipment.coffee_batches.empty?
        gaps << :no_origin if shipment.origin_missing?
        gaps << :not_received unless shipment.received?
        gaps << :no_costs if shipment.costs.empty? && shipment.expenses.empty? && shipment.trip_price.nil?
        sale = shipment.active_sale_line&.sale
        gaps << :not_sold if shipment.received? && sale.nil?
        gaps << :unpaid if sale && sale.balance_due.positive?
        gaps
      end
  end
end
