# Nothing takes more coffee than there is (Fernando, 2026-11-18: «todo debe
# coincidir y no pasar los límites»), once that coffee state and warehouse
# were counted (StockCount): a shipment, a process or a transfer whose net
# pounds pass what there is is not saved. Before the first count it only
# warns in the forms, as it did (the stock could not be trusted yet).
#
# What there is: the net stock of that state and warehouse at the moment
# it takes the coffee and now (a move dated back cannot take what later
# moves already took), without what the record itself took when saved
# before.
module StockGuard
  EPSILON = BigDecimal("0.005")

  # Adds the error to `record` when `net` passes what there is.
  # `before`: [moment, net] it took as saved before (to give back), or nil.
  def self.check(record, coffee_state:, warehouse:, at:, net:, before: nil)
    return if net.to_d <= 0 || warehouse.nil? || at.nil? || !coffee_state.in?(Purchase::COFFEE_STATES)
    return unless StockCount.counted?(coffee_state, warehouse.id, at)

    available = [ at, Time.current ].map do |moment|
      stock = CoffeeStock.new(warehouse:, at: moment).row(coffee_state).stock.to_d
      before && before.first && before.first <= moment ? stock + before.last.to_d : stock
    end.min
    return if net.to_d <= available + EPSILON

    record.errors.add(:base, I18n.t("errors.messages.over_stock", state: Purchase.human_attribute_name("coffee_state/#{coffee_state}"),
                                                                  warehouse: warehouse.name, available: format_pounds([ available, 0 ].max),
                                                                  net: format_pounds(net)))
  end

  def self.format_pounds(value) = ActiveSupport::NumberHelper.number_to_rounded(value, precision: 2, delimiter: ",")
end
