# Where a purchase is in the business's daily flow, as the client describes
# it: weigh (register) → invoice → mark as paid. Retention at season end is
# still an open point, so it is not a step yet.
class TradingLifecycle
  STAGES = %w[registered invoiced paid].freeze

  attr_reader :stage

  def self.for_purchase(purchase)
    return new("registered") unless purchase.invoice

    for_invoice(purchase.invoice)
  end

  def self.for_invoice(invoice)
    new(invoice.paid? ? "paid" : "invoiced")
  end

  def initialize(stage)
    raise ArgumentError, "unknown stage #{stage}" unless STAGES.include?(stage)

    @stage = stage
  end

  # :done for reached steps, :next for the one to do now, :upcoming after it.
  def status(step)
    reached = STAGES.index(stage)
    index = STAGES.index(step)
    return :done if index <= reached

    index == reached + 1 ? :next : :upcoming
  end

  def next_stage
    STAGES[STAGES.index(stage) + 1]
  end

  def complete?
    next_stage.nil?
  end

  def step_number(step)
    STAGES.index(step) + 1
  end
end
