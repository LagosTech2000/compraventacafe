# «Combustible» (Fernando, 2026-11-22: «litros dispensados diariamente»):
# what went into the vehicles of the business's fuel and oil (uses of the
# business with a vehicle, SupplyExit.dispatches), by day and by vehicle,
# in units and in lempiras, and what is left in the warehouse. This month
# by default. Not a paged list: it sums every dispatch filtered.
#
# Its cost: each unit at the average cost of everything that came in of
# that supply (Supply.average_costs; confirmed by Fernando, 2026-11-22).
class FuelDispatchFilter < ListFilter
  Row = Data.define(:key, :supply, :quantity, :cost, :dispatches)

  field :from, :date, default: -> { Time.zone.today.beginning_of_month }
  field :to, :date
  field :vehicle_id, :id
  field :supply_id, :id

  # The lines dispatched in the period, with their exit, vehicle and supply.
  def lines
    @lines ||= begin
      scope = SupplyExitLine.joins(:supply_exit).merge(SupplyExit.dispatches)
      scope = scope.where(supply_exits: { exited_on: from.. }) if from
      scope = scope.where(supply_exits: { exited_on: ..to }) if to
      scope = scope.where(supply_exits: { vehicle_id: }) if vehicle_id
      scope = scope.where(supply_id:) if supply_id
      scope.includes(:supply, supply_exit: { vehicle: :vehicle_type }).to_a
    end
  end

  def costs = @costs ||= Supply.average_costs(lines.map(&:supply_id).uniq)

  # One row per day and supply, the latest day first.
  def by_day = rows { [ it.supply_exit.exited_on ] }.sort_by { [ -it.key.first.jd, it.supply.name ] }

  # One row per vehicle and supply, the one that took the most first.
  def by_vehicle = rows { [ it.supply_exit.vehicle ] }.sort_by { [ -it.quantity, it.key.first.plate ] }

  # One row per supply: what went out in the period.
  def totals = rows { [] }.sort_by { it.supply.name }

  def total_cost = lines.sum { cost_of(it) }

  # What is left in the warehouse of each supply of the business.
  def stock
    Supply.of_the_business.active.or(Supply.of_the_business.where(id: lines.map(&:supply_id))).ordered
          .map { [ it, SupplyStock.in_warehouse(it.id) ] }
  end

  private
    def cost_of(line) = (line.quantity.to_d * costs.fetch(line.supply_id, 0).to_d).round(2)

    def rows(&key)
      lines.group_by { [ *key.call(it), it.supply ] }.map do |grouping, group|
        Row.new(key: grouping[0..-2], supply: grouping.last, quantity: group.sum { it.quantity.to_d },
                cost: group.sum { cost_of(it) }, dispatches: group.map(&:supply_exit_id).uniq.size)
      end
    end
end
