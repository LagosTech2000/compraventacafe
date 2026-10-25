# Sales list (Comercialización → Ventas). Voided ones only with the
# "voided" status.
class SaleFilter < ListFilter
  field :from, :date
  field :to, :date
  field :season_year, :id
  field :q, :text
  field :buyer_id, :id
  field :coffee_state, :choice, in: Purchase::COFFEE_STATES
  field :payment_status, :choice, in: Sale::FILTER_STATUSES

  PAID = "COALESCE((SELECT SUM(sale_payments.amount) FROM sale_payments WHERE sale_payments.sale_id = sales.id), 0)".freeze

  SORTS = {
    number: "sales.number", sold_on: "sales.sold_on",
    buyer: { sql: text("buyers.name"), joins: :buyer },
    coffee_state: "sales.coffee_state", net: "sales.net_weight", quintals: "sales.net_weight",
    price: "sales.unit_price", difference: "sales.net_weight - sales.origin_net_weight",
    total: "sales.total", balance: "sales.total - #{PAID}",
    payment_status: %w[sales.voided_at sales.payment_status]
  }.freeze
  sorts(**SORTS)

  def apply(scope)
    scope = scope.where(sold_on: from..to) if from || to
    scope = scope.in_season(Season.new(season_year)) if season_year
    scope = search(scope) if q
    scope = scope.where(buyer_id:) if buyer_id
    scope = scope.where(coffee_state:) if coffee_state
    scope = payment_status ? scope.with_payment_status(payment_status) : scope.active
    scope.includes(:buyer, :payments).newest_first
  end

  private
    def search(scope)
      number = q.to_s.delete("^0-9").presence&.to_i
      conditions = scope.where(buyer_id: Buyer.where("buyers.name ILIKE ?", like(q)).select(:id))
                        .or(scope.where("sales.buyer_document_number ILIKE ?", like(q)))
      number ? conditions.or(scope.where(number:)) : conditions
    end
end
