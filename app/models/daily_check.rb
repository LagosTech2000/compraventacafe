# «¿Cuadra hoy?» (Fernando, 2026-11-18), a card of the Inicio for
# administrators: what still keeps today from adding up, each line opening
# where it is fixed. Only reads what the system keeps.
class DailyCheck
  # `ok`: nothing to do; `count`/`amount`: what the line says.
  Line = Data.define(:key, :ok, :count, :amount, :path)

  RECENT_DAYS = 30

  def initialize(day: Time.zone.today)
    @day = day
  end

  def lines
    @lines ||= [ stock_counts, cash_counts, uninvoiced, unpaid, shipments_without_lots, missing_reasons, negative_accounts ]
  end

  def ok? = lines.all?(&:ok)

  private
    # Coffee in stock (state and warehouse) without a count today.
    def stock_counts
      stocked = CoffeeStock.net_by_warehouse(@day).select { |_, net| net.positive? }.keys
      counted = StockCount.active.where(counted_at: @day.all_day).distinct.pluck(:warehouse_id, :coffee_state)
      missing = stocked - counted
      Line.new(key: :stock_counts, ok: missing.empty?, count: missing.size, amount: nil, path: [ :sales_stock_counts_path ])
    end

    # Cash boxes without a count today, or with a difference.
    def cash_counts
      boxes = MoneyAccount.active.where(kind: "cash").to_a
      counts = CashCount.where(money_account: boxes, counted_on: @day).group_by(&:money_account_id)
      missing = boxes.count { counts[it.id].blank? }
      difference = counts.values.sum { |list| list.max_by(&:id).then { it.counted_amount - it.system_balance } }
      Line.new(key: :cash_counts, ok: missing.zero? && difference.zero?, count: missing, amount: difference, path: [ :finance_money_accounts_path ])
    end

    def uninvoiced
      count = Purchase.uninvoiced.on(@day).count
      Line.new(key: :uninvoiced, ok: count.zero?, count:, amount: nil, path: [ :trading_purchases_path, { status: "uninvoiced" } ])
    end

    # Purchases of the day invoiced and not paid in full.
    def unpaid
      count = Purchase.active.on(@day).where(invoice_id: Invoice.active.where.not(payment_status: "paid").select(:id)).count
      Line.new(key: :unpaid, ok: count.zero?, count:, amount: nil, path: [ :trading_purchases_path, { status: "pending" } ])
    end

    def shipments_without_lots
      count = Shipment.active.where(departed_at: @day.all_day).where.not(id: CoffeeBatch.where.not(shipment_id: nil).select(:shipment_id)).count
      Line.new(key: :shipments_without_lots, ok: count.zero?, count:, amount: nil, path: [ :sales_shipments_path, { shrink: "no_batches" } ])
    end

    # Shipments of the last days over a tolerance without their reason.
    # (Shipment#missing_reasons, in a few queries.)
    def missing_reasons
      shipments = Shipment.active.where(departed_at: (@day - RECENT_DAYS).beginning_of_day..@day.end_of_day).to_a
      ids = shipments.map(&:id)
      shrinks = Shipment.shrinks(ids)
      stock = Shipment.stock_weights(ids)
      shrink_tolerance = WeightTolerance.shrink_percent
      count = shipments.count do |shipment|
        shrink_net = shrinks.dig(shipment.id, 1)
        lots_net = stock.dig(shipment.id, 0)
        shrink_over = shrink_tolerance && shrink_net && lots_net&.positive? && (shrink_net * 100 / lots_net).round(2).abs > shrink_tolerance
        (shrink_over && shipment.shrink_reason.blank?) || (shipment.over_tolerance? && shipment.difference_reason.blank?)
      end
      Line.new(key: :missing_reasons, ok: count.zero?, count:, amount: nil, path: [ :sales_shipments_path ])
    end

    def negative_accounts
      balances = AccountBalance.new(as_of: @day)
      count = MoneyAccount.active.count { balances.for(it).negative? }
      Line.new(key: :negative_accounts, ok: count.zero?, count:, amount: nil, path: [ :finance_opening_balances_path ])
    end
end
