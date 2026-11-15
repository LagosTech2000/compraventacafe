module Maintenance
  # integrity:money — of each account, the balance (AccountBalance) must be
  # its opening balance plus what came in minus what went out in the ledger
  # (MoneyMovements), and what has no account must match too. Also: opening
  # balances at zero, movements dated before an account's opening balance
  # (both count: it may be counted twice), and payments of something voided
  # that still count. Reads only.
  class Money < Task
    self.key = "integrity:money"
    self.tier = :check
    self.area = :finance

    def sections
      balances = AccountBalance.new
      accounts = MoneyAccount.order(:name).to_a
      account_lines = accounts.map do |account|
        movements = MoneyMovements.new(account: account.id).all
        expected = account.opening_balance.to_d + movements.sum(0.to_d, &:net)
        balance = balances.for(account)
        before = movements.count { it.date < account.opening_on }
        line = same?(balance, expected) ? t(:matches, account: account.name, balance: money(balance)) : t(:differs, account: account.name, balance: money(balance), ledger: money(expected))
        line += " #{t(:before_opening, count: before, date: day(account.opening_on))}" if before.positive?
        line += " #{t(:zero_opening)}" if account.opening_balance.to_d.zero?
        [ line, same?(balance, expected) ? (before.positive? || account.opening_balance.to_d.zero? ? "warn" : "ok") : "bad" ]
      end
      unassigned = MoneyMovements.new(account: :none).all.sum(0.to_d, &:net)
      none_ok = same?(balances.unassigned.net, unassigned)
      account_lines << [ none_ok ? t(:none_matches, amount: money(unassigned)) : t(:none_differs, balance: money(balances.unassigned.net), ledger: money(unassigned)), none_ok ? "ok" : "bad" ]

      [ section(t(:accounts), Maintenance.worst(account_lines.map(&:last)), account_lines.map(&:first)), voided_section ]
    end

    private
      # Money of something voided that still counts in a balance.
      def voided_section
        found = {
          sale_payments: SalePayment.joins(:sale).where.not(sales: { voided_at: nil }).count,
          shipment_costs: ShipmentCost.joins(:shipment).where.not(shipments: { voided_at: nil }).count,
          processing_costs: ProcessingCost.joins(:coffee_conversion).where.not(coffee_conversions: { voided_at: nil }).count,
          invoice_payments: InvoicePayment.joins(:invoice).where.not(invoices: { voided_at: nil }).count
        }.select { |_, count| count.positive? }
        return section(t(:voided), "ok", [ t(:voided_none) ]) if found.empty?

        section(t(:voided), "bad", found.map { |source, count| t("voided_found.#{source}", count:) })
      end
  end
end
