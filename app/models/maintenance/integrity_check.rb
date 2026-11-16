module Maintenance
  # integrity:check — every check at once (inventory, shipments, money,
  # cash counts, expenses) plus the invoices, haulers and lots: a traffic
  # light per part. Reads only; meant to run every week.
  class IntegrityCheck < Task
    self.key = "integrity:check"
    self.tier = :check
    self.area = :general

    PARTS = [ Inventory, Shipments, Sales, Money, CashCounts, Expenses ].freeze

    def sections
      parts = PARTS.flat_map do |task|
        task.new.sections.map { Section.new(title: "#{task.title} · #{it.title}", status: it.status, lines: it.lines) }
      end
      own = [ invoices_section, haulers_section, lots_section ]
      [ overview(parts + own) ] + own + parts
    end

    private
      def overview(sections)
        counts = sections.map(&:status).tally
        lines = %w[bad warn ok].filter_map { counts[it] ? t("overview.#{it}", count: counts[it]) : nil }
        section(t(:overview_title), Maintenance.worst(sections.map(&:status)), lines)
      end

      # The payment status kept against what its payments say now, and
      # voided invoices with purchases still active.
      def invoices_section
        paid = InvoicePayment.group(:invoice_id).sum(:amount)
        totals = Purchase.where.not(invoice_id: nil).group(:invoice_id).sum(:total)
        loans = LoanPayment.joins(:purchase).group("purchases.invoice_id").sum(:amount)
        lines = Invoice.active.order(:number).filter_map do |invoice|
          due = totals.fetch(invoice.id, 0).to_d - loans.fetch(invoice.id, 0).to_d
          given = paid.fetch(invoice.id, 0).to_d
          expected = if given >= due then "paid" elsif given.positive? then "partial" else "pending" end
          next if expected == invoice.payment_status

          t(:invoice_status, number: invoice.display_number, kept: Invoice.human_attribute_name("payment_status/#{invoice.payment_status}"),
                             expected: Invoice.human_attribute_name("payment_status/#{expected}"))
        end
        orphans = Purchase.active.joins(:invoice).where.not(invoices: { voided_at: nil }).count
        lines << t(:orphans, count: orphans) if orphans.positive?
        section(t(:invoices_title), lines.any? ? "bad" : "ok", lines.presence || [ t(:invoices_ok) ])
      end

      # A hauler never owes the business: what was paid is not over what he earned.
      def haulers_section
        owing = Hauler.includes(:person).select { it.balance.negative? }
        lines = owing.map { t(:hauler_owes, id: it.id, amount: money(-it.balance)) }
        section(t(:haulers_title), lines.any? ? "bad" : "ok", lines.presence || [ t(:haulers_ok) ])
      end

      # No invoice past 100 % between lots and no lot past its limit.
      def lots_section
        over = CoffeeBatchInvoice.group(:invoice_id).having("SUM(percent) > 100").count.keys
        lines = Invoice.where(id: over).map { t(:invoice_over, number: it.display_number) }
        totals = CoffeeBatch::Totals.by_batch(CoffeeBatch.pluck(:id))
        CoffeeBatch.order(:number).each do |batch|
          gross = totals[batch.id]&.gross.to_d
          lines << t(:lot_over, label: batch.label, gross: pounds(gross), limit: pounds(batch.gross_limit)) if gross > batch.gross_limit.to_d + 0.01
        end
        section(t(:lots_title), lines.any? ? "bad" : "ok", lines.presence || [ t(:lots_ok) ])
      end
  end
end
