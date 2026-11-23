# Closing a lot without a shipment or a process (Fernando, 2026-11-22: lot
# 27's invoices never went on a shipment, by the business's own mistake):
# it stops being offered (shipments, processes, «¿Qué café lleva?», «Facturar
# compras») and its invoices and processes stay in it; its purchases stay
# active, so the producers keep their QQ.
#
# `gone`: its coffee is no longer in the warehouse. Then a count adjustment
# (StockCount, reason «Otro») takes its gross pounds out of that state and
# warehouse, and enters everything a count enters (stock, lots, kardex,
# checks). Without it only the lot closes: the stock does not change.
#
# Reopening (administrators) voids that count, while no later count was
# made on it, and leaves the lot free again.
class CoffeeBatchClosing
  attr_reader :batch, :errors

  def initialize(batch:, user:)
    @batch = batch
    @user = user
    @errors = []
  end

  def close(reason:, gone:)
    reason = reason.to_s.squish
    return fail_with(I18n.t("sales.coffee_batch_closings.errors.reason")) if reason.empty?
    return fail_with(I18n.t("sales.coffee_batch_closings.errors.taken")) if batch.taken? || batch.closed?

    CoffeeBatch.transaction do
      batch.lock!
      count = (take_out(reason) if gone)
      batch.update!(closed_at: Time.current, closed_by: @user, close_reason: reason.first(200), stock_count: count)
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    fail_with(error.record.errors.full_messages.to_sentence)
  end

  def reopen
    CoffeeBatch.transaction do
      batch.lock!
      batch.stock_count&.void!(@user, reason: I18n.t("sales.coffee_batch_closings.reopen_reason", batch: batch.label))
      batch.update!(closed_at: nil, closed_by: nil, close_reason: nil, stock_count: nil)
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    fail_with(error.record.errors.full_messages.to_sentence)
  end

  # What is left of its state in its warehouse once its coffee is out.
  def self.counted_without(batch, at: Time.current)
    there = CoffeeStock.new(warehouse: batch.warehouse, at:).row(batch.coffee_state).gross_stock.to_d
    [ there - batch.gross_weight.to_d, 0 ].max.round(2)
  end

  private
    def take_out(reason)
      at = Time.current.change(sec: 0)
      StockCount.create!(warehouse: batch.warehouse, coffee_state: batch.coffee_state, counted_at: at,
                         counted_gross: self.class.counted_without(batch, at:), reason: "other",
                         reason_detail: I18n.t("sales.coffee_batch_closings.count_detail", batch: batch.label, reason:).first(200),
                         created_by: @user)
    end

    def fail_with(message)
      @errors << message
      false
    end
end
