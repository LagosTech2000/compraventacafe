# Lots of purchased coffee (Fernando, 2026-11-13: «los lotes se deben
# mostrar por fecha»): the newest first, by date, coffee state, warehouse,
# whether they went on a shipment, and number.
class CoffeeBatchFilter < ListFilter
  STATUSES = %w[free shipped closed].freeze

  field :q, :text
  field :from, :date
  field :to, :date
  field :coffee_state, :choice, in: Purchase::COFFEE_STATES
  field :warehouse_id, :id
  field :status, :choice, in: STATUSES

  sorts number: "coffee_batches.number",
        batched_on: "coffee_batches.batched_on",
        coffee_state: "coffee_batches.coffee_state",
        warehouse: { sql: text("warehouses.name"), joins: :warehouse },
        gross_limit: "coffee_batches.gross_limit",
        gross: CoffeeBatch.share_sql(:gross_weight),
        net: CoffeeBatch.share_sql(:net_weight),
        value: CoffeeBatch.share_sql(:total),
        shipment: "coffee_batches.shipment_id"

  def apply(scope)
    scope = scope.where(batched_on: from..) if from
    scope = scope.where(batched_on: ..to) if to
    scope = scope.where(coffee_state:) if coffee_state
    scope = scope.where(warehouse_id:) if warehouse_id
    scope = case status
    when "free" then scope.free
    when "shipped" then scope.where.not(shipment_id: nil).or(scope.where.not(coffee_conversion_id: nil))
    when "closed" then scope.closed
    else scope
    end
    scope = search(scope) if q
    scope.includes(:warehouse, :shipment, :processing).newest_first
  end

  private
    # By number ("0012" or "12"), or by the producer of one of its invoices.
    def search(scope)
      producers = Producer.where(person_id: Person.picker_search(q).select(:id)).select(:id)
      by_producer = scope.where(id: CoffeeBatchInvoice.joins(:invoice).where(invoices: { producer_id: producers }).select(:coffee_batch_id))
      q.match?(/\A\d+\z/) ? by_producer.or(scope.where(number: q.to_i)) : by_producer
    end
end
