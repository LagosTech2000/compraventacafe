module Maintenance
  # batches:backfill — a lot for each past shipment that has none (Fernando
  # chose it, 2026-11-15; to run it the client decides the cutoff date of
  # the lots): the invoices of its coffee state, with every purchase in its
  # warehouse and bought by the end of the day it left, the oldest purchase first, up to the
  # gross pounds of its local scale (the last one in a part). An
  # approximation: nobody wrote down which invoices went on each truck.
  #
  # What it changes: those shipments take from the stock their lots'
  # coffee, not the oldest (the preview says by how much each coffee state
  # moves), and get a cost. Their shrink is not real (the lot is filled up
  # to the local scale's weight). Shipments without the local scale are
  # left out. Undone by removing the lots it made.
  class BatchesBackfill < Task
    self.key = "batches:backfill"
    self.tier = :decision
    self.area = :sales
    param :from, :date
    param :to, :date

    Plan = Data.define(:shipment, :target, :shares, :missing) do
      def taken_gross = shares.sum(0.to_d) { it[:gross] }
      def taken_net = shares.sum(0.to_d) { it[:net] }
    end

    def sections
      plans = plan
      [ summary_section(plans, applied: false), skipped_section ] + plans.map { shipment_section(it) }
    end

    def apply!
      user = creator
      ids = plan.select { it.shares.any? }.map do |entry|
        shipment = entry.shipment
        batch = CoffeeBatch.create!(warehouse_id: shipment.warehouse_id, coffee_state: shipment.coffee_state, gross_limit: entry.target,
                                    batched_on: shipment.departed_at.in_time_zone.to_date, created_by: user,
                                    observations: t(:observation))
        entry.shares.each { batch.batch_invoices.create!(invoice: it[:invoice], percent: it[:percent], created_by: user) }
        batch.update!(shipment:)
        batch.id
      end
      { "batch_ids" => ids }
    end

    def sections_after_apply(changes)
      [ summary_section(plan, applied: true, made: changes["batch_ids"].size) ] + plan.map { shipment_section(it) }
    end

    def self.revert!(changes)
      CoffeeBatch.where(id: changes["batch_ids"]).find_each.count do |batch|
        batch.update!(shipment: nil)
        batch.destroy!
      end
    end

    private
      def creator = Current.user || User.find_by(id: User::DATA_EXPORTER_ID) || User.where(admin: true, active: true).order(:id).first!

      def shipments
        scope = Shipment.active.where.not(id: CoffeeBatch.where.not(shipment_id: nil).select(:shipment_id)).includes(:warehouse)
        scope = scope.where(departed_at: date_param(:from).in_time_zone.beginning_of_day..) if params["from"]
        scope = scope.where(departed_at: ..date_param(:to).in_time_zone.end_of_day) if params["to"]
        scope.order(:departed_at, :id)
      end

      # Each shipment's invoices, the oldest first; what one shipment takes
      # of an invoice is not free for the next.
      def plan
        @plan ||= begin
          used = Hash.new(0.to_d).merge(CoffeeBatchInvoice.used_by_invoice.transform_values(&:to_d))
          shipments.where.not(origin_gross_weight: nil).map do |shipment|
            probe = CoffeeBatch.new(coffee_state: shipment.coffee_state, warehouse_id: shipment.warehouse_id)
            eligible = CoffeeBatchInvoice.eligible_invoices(probe).select(:id)
            # Its purchases' pounds and dates: only invoices whose every purchase was bought by the end of the day it left.
            weights = Purchase.active.where(invoice_id: eligible).group(:invoice_id)
                              .having("MAX(purchased_at) <= ?", shipment.departed_at.in_time_zone.end_of_day)
                              .pluck(:invoice_id, Arel.sql("SUM(gross_weight)"), Arel.sql("SUM(net_weight)"), Arel.sql("MIN(purchased_at)"))
                              .to_h { |id, gross, net, first| [ id, [ gross.to_d, net.to_d, first ] ] }
            invoices = Invoice.where(id: weights.keys).sort_by { [ weights[it.id].last, it.number ] }
            left = shipment.origin_gross_weight.to_d
            shares = []
            invoices.each do |invoice|
              break unless left > 0.005

              gross, net, = weights[invoice.id]
              free = 100 - used[invoice.id]
              next unless gross&.positive? && free.positive?

              percent = ([ free, left / gross * 100 ].min * 10_000).floor / 10_000.to_d
              next unless percent.positive?

              taken = (gross * percent / 100).round(6)
              shares << { invoice:, percent:, gross: taken, net: (net * percent / 100).round(6) }
              used[invoice.id] += percent
              left -= taken
            end
            Plan.new(shipment:, target: shipment.origin_gross_weight.to_d, shares:, missing: [ left, 0 ].max)
          end
        end
      end

      def summary_section(plans, applied:, made: nil)
        with = plans.select { it.shares.any? }
        lines = [ applied ? t(:made, count: made) : t(:would_make, count: with.size, total: plans.size) ]
        lines << t(:range, from: params["from"] ? day(date_param(:from)) : t(:start), to: params["to"] ? day(date_param(:to)) : t(:today))
        lines << t(:invoices, count: with.sum { it.shares.size })
        # What each coffee state's stock moves: these shipments take their lots' net pounds instead of their local scale's.
        with.group_by { it.shipment.coffee_state }.each do |state, entries|
          change = entries.sum(0.to_d) { it.shipment.origin_net_weight.to_d - it.taken_net }
          lines << t(:stock_change, state: Purchase.human_attribute_name("coffee_state/#{state}"), pounds: pounds(change))
        end
        lines << t(:shrink_warning)
        section(t(:summary), applied ? "ok" : "warn", lines)
      end

      def skipped_section
        without_scale = shipments.where(origin_gross_weight: nil).map(&:display_number)
        lines = without_scale.any? ? [ t(:no_scale, numbers: without_scale.join(", ")) ] : [ t(:none_skipped) ]
        section(t(:skipped), without_scale.any? ? "warn" : "ok", lines)
      end

      def shipment_section(entry)
        shipment = entry.shipment
        title = t(:shipment, number: shipment.display_number, date: day(shipment.departed_at.in_time_zone), state: shipment.human_coffee_state,
                             warehouse: shipment.warehouse.name)
        lines = [ t(:target, gross: pounds(entry.target), taken: pounds(entry.taken_gross)) ]
        lines += entry.shares.map { t(:share, number: it[:invoice].display_number, percent: percent_text(it[:percent]), gross: pounds(it[:gross]), net: pounds(it[:net])) }
        lines << t(:missing, gross: pounds(entry.missing)) if entry.missing > 0.005
        status = if entry.shares.empty? then "bad"
        elsif entry.missing > 0.005 then "warn"
        else "ok"
        end
        section(title, status, lines)
      end
  end
end
