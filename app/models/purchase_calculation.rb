# Net weight and total of a coffee purchase. Tare follows the client's Excel
# macro (modIngresoCafeAuto.RecalcularFilaIngreso); the rest depends on the
# coffee state:
#
#   sacks      = gross / 165                  (a full sack weighs 165 lb)
#   tare       = ceil(sacks) × 1 lb           (1 lb per sack, rounded up)
#
#   Wet and dry parchment:
#   net_weight = (gross − tare) × (1 − humidity%) × (1 − damage%)
#   damage_weight = (gross − tare) × (1 − humidity%) × damage%   (what damage takes off)
#   Cherry:
#   net_weight = (gross − tare) × yield       (0.186 by default)
#
#   quintals   = net_weight / 125             (QQ)
#   total      = net_weight × price_per_pound
#
# The net weight never goes below 0.
class PurchaseCalculation
  SACK_WEIGHT = 165
  TARE_PER_SACK = 1
  QUINTAL_WEIGHT = 125

  attr_reader :sacks, :tare, :net_weight, :damage_weight, :quintals, :total

  def self.quintals(net_weight)
    (BigDecimal(net_weight.to_s) / QUINTAL_WEIGHT).round(2)
  end

  def initialize(coffee_state:, gross_weight:, price_per_pound:, humidity_percent: nil, damage_percent: nil, yield_factor: nil)
    gross = BigDecimal(gross_weight.to_s)
    price = BigDecimal(price_per_pound.to_s)

    @sacks = (gross / SACK_WEIGHT).round(4)
    @tare = BigDecimal((gross / SACK_WEIGHT).ceil * TARE_PER_SACK)
    @net_weight = [ (gross - @tare) * net_factor(coffee_state, humidity_percent, damage_percent, yield_factor), 0 ].max.round(2)
    @damage_weight = coffee_state == "cherry" ? nil : damage_weight_of(gross, humidity_percent, damage_percent)
    @quintals = self.class.quintals(@net_weight)
    @total = (@net_weight * price).round(2)
  end

  private
    def net_factor(coffee_state, humidity_percent, damage_percent, yield_factor)
      return BigDecimal(yield_factor.to_s) if coffee_state == "cherry"

      (1 - percent(humidity_percent)) * (1 - percent(damage_percent))
    end

    def damage_weight_of(gross, humidity_percent, damage_percent)
      before_damage = [ (gross - @tare) * (1 - percent(humidity_percent)), 0 ].max
      (before_damage * percent(damage_percent)).round(2)
    end

    def percent(value)
      BigDecimal(value.to_s) / 100
    end
end
