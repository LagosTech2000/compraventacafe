class BuyerFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  field :q, :text
  field :kind, :choice, in: Buyer::KINDS
  field :status, :choice, in: STATUSES, default: "active"

  SOLD = "(SELECT COALESCE(SUM(sales.total), 0) FROM sales WHERE sales.buyer_id = buyers.id AND sales.voided_at IS NULL)".freeze
  COLLECTED = <<~SQL.squish.freeze
    (SELECT COALESCE(SUM(sale_payments.amount), 0) FROM sale_payments JOIN sales ON sales.id = sale_payments.sale_id
     WHERE sales.buyer_id = buyers.id AND sales.voided_at IS NULL)
  SQL
  SHIPPED = "(SELECT COALESCE(SUM(shipments.origin_net_weight), 0) FROM shipments WHERE shipments.buyer_id = buyers.id AND shipments.voided_at IS NULL)".freeze

  sorts name: text("buyers.name"), kind: "buyers.kind", rtn: "buyers.rtn", phone: "buyers.phone",
        shipped: SHIPPED, sold: SOLD, balance: "#{SOLD} - #{COLLECTED}"

  def apply(scope)
    scope = scope.where("buyers.name ILIKE :q OR buyers.rtn ILIKE :q OR buyers.contact_name ILIKE :q", q: like(q)) if q
    scope = scope.where(kind:) if kind
    scope = scope.where(active: status == "active") if status
    scope.select("buyers.*", "#{SHIPPED} AS shipped_total", "#{SOLD} AS sold_total", "#{SOLD} - #{COLLECTED} AS balance_total")
         .order(:name)
  end
end
