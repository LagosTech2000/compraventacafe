# Where a purchase is in the business's daily flow, as the client describes
# it: weigh (register) → invoice → mark as paid. Retention at season end is
# still an open point, so it is not a step yet.
class TradingLifecycle
  include LifecycleSteps

  STAGES = %w[registered invoiced paid].freeze

  def self.for_purchase(purchase)
    return new("registered") unless purchase.invoice

    for_invoice(purchase.invoice)
  end

  def self.for_invoice(invoice)
    new(invoice.paid? ? "paid" : "invoiced")
  end
end
