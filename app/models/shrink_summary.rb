# The shrink (merma, Fernando, 2026-11-13) of some shipments: what their
# lots' purchases say − what their local scale gave, gross and net. Only
# the shipments with lots and the local scale count; positive is weight
# lost («pérdida»), negative weight gained («ganancia»). Sums in SQL.
class ShrinkSummary
  Group = Data.define(:count, :gross, :net)

  # Shipments that have lots and their local scale.
  def self.measurable(scope)
    scope.where.not(origin_net_weight: nil).where(id: CoffeeBatch.where.not(shipment_id: nil).select(:shipment_id))
  end

  def initialize(shipments)
    @shipments = shipments.unscope(:includes, :order)
  end

  def all = @all ||= group(self.class.measurable(@shipments))
  def loss = @loss ||= group(self.class.measurable(@shipments).where("#{Shipment::SHRINK_NET_SQL} > 0"))
  def gain = @gain ||= group(self.class.measurable(@shipments).where("#{Shipment::SHRINK_NET_SQL} < 0"))
  def without_batches = @without_batches ||= @shipments.active.where.not(id: CoffeeBatch.where.not(shipment_id: nil).select(:shipment_id)).count

  # Net shrink as a percent of what the lots' purchases say (nil without any).
  def percent
    batches_net = self.class.measurable(@shipments).sum(Arel.sql(Shipment.batches_sql(:net_weight))).to_d
    batches_net.positive? ? (all.net * 100 / batches_net).round(2) : nil
  end

  def any? = all.count.positive?

  private
    def group(scope)
      count, gross, net = scope.pick(Arel.sql("COUNT(*)"), Arel.sql("SUM(#{Shipment::SHRINK_GROSS_SQL})"), Arel.sql("SUM(#{Shipment::SHRINK_NET_SQL})"))
      Group.new(count: count.to_i, gross: gross.to_d.round(2), net: net.to_d.round(2))
    end
end
