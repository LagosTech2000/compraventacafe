module Maintenance
  # integrity:cash_counts — each cash count kept the system's balance of
  # that day; recomputed today it should be the same. When it moved,
  # something was registered later with an earlier date, or moved to or
  # from that account (Consolidación). Reads only.
  class CashCounts < Task
    self.key = "integrity:cash_counts"
    self.tier = :check
    self.area = :finance

    def sections
      counts = CashCount.includes(:money_account).order(:counted_on, :id).to_a
      return [ section(t(:title), "warn", [ t(:none) ]) ] if counts.empty?

      results = counts.map do |count|
        now = AccountBalance.new(as_of: count.counted_on).for(count.money_account)
        kept = count.system_balance.to_d
        moved = !same?(now, kept)
        [ t(moved ? :moved : :holds, id: count.id, account: count.money_account.name, date: day(count.counted_on),
                                     kept: money(kept), now: money(now), difference: money(now - kept)), moved ? "bad" : "ok" ]
      end
      [ section(t(:title), Maintenance.worst(results.map(&:last)), results.map(&:first)) ]
    end
  end
end
