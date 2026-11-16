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
      # Only a shipment its lot fills whole gets one (Fernando, 2026-11-16):
      # a part-filled lot would leave the rest of its coffee in the stock.
      def complete? = shares.any? && missing <= 0.005
    end

    def sections
      plans = plan
      [ summary_section(plans, applied: false), skipped_section ] + plans.map { shipment_section(it) }
    end

    def apply!
      user = creator
      ids = plan.select(&:complete?).map do |entry|
        shipment = entry.shipment
        batch = CoffeeBatch.create!(warehouse_id: shipment.warehouse_id, coffee_state: shipment.coffee_state, gross_limit: entry.target,
                                    batched_on: shipment.departed_at.in_time_zone.to_date, created_by: user,
                                    observations: t(:observation))
        entry.shares.each do |share|
          if share[:conversion]
            batch.batch_conversions.create!(coffee_conversion: share[:conversion], percent: share[:percent], created_by: user)
          else
            batch.batch_invoices.create!(invoice: share[:invoice], percent: share[:percent], created_by: user)
          end
        end
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

      # Each shipment's invoices and finished processes (Fernando, 2026-11-16),
      # the oldest first; what one shipment takes is not free for the next.
      # A shipment that cannot be filled whole takes nothing.
      def plan
        @plan ||= begin
          used = Hash.new(0.to_d).merge(CoffeeBatchInvoice.used_by_invoice.transform_values(&:to_d).transform_keys { [ :invoice, it ] })
          CoffeeBatchConversion.used_by_conversion.each { |id, percent| used[[ :conversion, id ]] = percent.to_d }
          shipments.where.not(origin_gross_weight: nil).map do |shipment|
            departed = shipment.departed_at.in_time_zone.end_of_day
            left = shipment.origin_gross_weight.to_d
            shares = []
            sources_for(shipment, departed).each do |source|
              break unless left > 0.005

              key = [ source[:kind], source[:record].id ]
              free = 100 - used[key]
              next unless source[:gross].positive? && free.positive?

              percent = ([ free, left / source[:gross] * 100 ].min * 10_000).floor / 10_000.to_d
              next unless percent.positive?

              taken = (source[:gross] * percent / 100).round(6)
              shares << { source[:kind] => source[:record], key:, percent:, gross: taken, net: (source[:net] * percent / 100).round(6) }
              left -= taken
            end
            entry = Plan.new(shipment:, target: shipment.origin_gross_weight.to_d, shares:, missing: [ left, 0 ].max)
            entry.shares.each { used[it[:key]] += it[:percent] } if entry.complete?
            entry
          end
        end
      end

      # What a shipment could take, the oldest first: invoices whose every
      # purchase was bought by the end of the day it left (by their first
      # purchase) and processes finished by then.
      def sources_for(shipment, departed)
        probe = CoffeeBatch.new(coffee_state: shipment.coffee_state, warehouse_id: shipment.warehouse_id)
        weights = Purchase.active.where(invoice_id: CoffeeBatchInvoice.eligible_invoices(probe).select(:id)).group(:invoice_id)
                          .having("MAX(purchased_at) <= ?", departed)
                          .pluck(:invoice_id, Arel.sql("SUM(gross_weight)"), Arel.sql("SUM(net_weight)"), Arel.sql("MIN(purchased_at)"))
                          .to_h { |id, gross, net, first| [ id, [ gross.to_d, net.to_d, first ] ] }
        invoices = Invoice.where(id: weights.keys).map do |invoice|
          gross, net, first = weights[invoice.id]
          { kind: :invoice, record: invoice, gross:, net:, at: first, order: invoice.number }
        end
        conversions = CoffeeBatchConversion.eligible_conversions(probe).where(finished_at: ..departed).map do |conversion|
          { kind: :conversion, record: conversion, gross: conversion.output_gross_weight.to_d, net: conversion.output_net_weight.to_d,
            at: conversion.finished_at, order: conversion.number }
        end
        (invoices + conversions).sort_by { [ it[:at], it[:kind] == :invoice ? 0 : 1, it[:order] ] }
      end

      def summary_section(plans, applied:, made: nil)
        with = plans.select(&:complete?)
        lines = [ applied ? t(:made, count: made) : t(:would_make, count: with.size, total: plans.size) ]
        incomplete = plans.reject(&:complete?)
        lines << t(:incomplete, count: incomplete.size, numbers: incomplete.map { it.shipment.display_number }.join(", ")) if incomplete.any?
        lines << t(:range, from: params["from"] ? day(date_param(:from)) : t(:start), to: params["to"] ? day(date_param(:to)) : t(:today))
        lines << t(:invoices, count: with.sum { |entry| entry.shares.count { it[:invoice] } })
        conversions = with.sum { |entry| entry.shares.count { it[:conversion] } }
        lines << t(:conversions, count: conversions) if conversions.positive?
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
        lines += entry.shares.map do |share|
          figures = { percent: percent_text(share[:percent]), gross: pounds(share[:gross]), net: pounds(share[:net]) }
          share[:conversion] ? t(:conversion_share, name: share[:conversion].audit_label, **figures) : t(:share, number: share[:invoice].display_number, **figures)
        end
        lines += [ t(:missing, gross: pounds(entry.missing)), t(:left_without_lot) ] unless entry.complete?
        status = entry.complete? ? "ok" : "warn"
        section(title, status, lines)
      end
  end
end
