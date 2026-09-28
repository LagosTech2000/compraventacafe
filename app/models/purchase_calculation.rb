# Net weight and total of a coffee purchase, as the client's current Excel
# macro computes them (modIngresoCafeAuto.RecalcularFilaIngreso):
#
#   sacks      = gross / 165                  (a full sack weighs 165 lb)
#   tare       = ceil(sacks) × 1 lb           (1 lb per sack, rounded up)
#   net_weight = (gross − tare) × (1 − humidity%)   (never below 0)
#   total      = net_weight × price_per_pound
#
# The same rule applies to every coffee state and ignores damage: how either
# changes the calculation is still an open question with the client.
class PurchaseCalculation
  SACK_WEIGHT = 165
  TARE_PER_SACK = 1

  attr_reader :sacks, :tare, :net_weight, :total

  def initialize(gross_weight:, humidity_percent:, price_per_pound:)
    gross = BigDecimal(gross_weight.to_s)
    humidity = BigDecimal(humidity_percent.to_s) / 100
    price = BigDecimal(price_per_pound.to_s)

    @sacks = (gross / SACK_WEIGHT).round(4)
    @tare = BigDecimal((gross / SACK_WEIGHT).ceil * TARE_PER_SACK)
    @net_weight = [ (gross - @tare) * (1 - humidity), 0 ].max.round(2)
    @total = (@net_weight * price).round(2)
  end
end
