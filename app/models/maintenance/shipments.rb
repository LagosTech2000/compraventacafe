module Maintenance
  # integrity:shipments — each shipment that is missing something for its
  # cost, shrink and scale difference to be known: lots, the local scale,
  # the buyer's scale, its expenses, its sale or its collection. Reads only.
  class Shipments < Task
    self.key = "integrity:shipments"
    self.tier = :check
    self.area = :sales

    # What blocks a figure (bad) and what is only incomplete (warn).
    BLOCKING = %i[no_lots no_origin late_lots repeated_note].freeze

    def sections
      shipments = Shipment.active.includes(:coffee_batches, :costs, :expenses, :warehouse, active_sale_line: :sale).order(:departed_at, :id).to_a
      @late = CoffeeBatch.latest_coffee(shipments.flat_map { it.coffee_batches.map(&:id) })
      @repeated = repeated_notes(shipments)
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
        # Coffee that came in after it left (Fernando, 2026-11-18).
        gaps << :late_lots if shipment.coffee_batches.any? { CoffeeBatch.after?(@late[it.id], shipment.departed_at) }
        gaps << :repeated_note if @repeated.include?(shipment.id)
        gaps << :no_origin if shipment.origin_missing?
        gaps << :not_received unless shipment.received?
        gaps << :no_costs if shipment.costs.empty? && shipment.expenses.empty? && shipment.trip_price.nil?
        sale = shipment.active_sale_line&.sale
        gaps << :not_sold if shipment.received? && sale.nil?
        gaps << :unpaid if sale && sale.balance_due.positive?
        gaps
      end

      # Shipments whose buyer's weight note is on another shipment of the same
      # buyer (without spaces, case or leading zeros).
      def repeated_notes(shipments)
        shipments.select { it.weight_note_number.present? }
                 .group_by { [ it.buyer_id, it.weight_note_number.gsub(/\s/, "").upcase.sub(/\A0+/, "") ] }
                 .values.select(&:many?).flatten.map(&:id).to_set
      end
  end
end
