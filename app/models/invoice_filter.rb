class InvoiceFilter < ListFilter
  field :from, :date
  field :to, :date
  field :season_year, :id
  field :q, :text
  field :zone_id, :id
  field :payment_status, :choice, in: Invoice::FILTER_STATUSES
  field :payment_method, :choice, in: Invoice::PAYMENT_METHODS

  # Every column of the invoices table (also on a producer's page).
  SORTS = {
    number: "invoices.number", date: "invoices.issued_on",
    producer: { sql: text("people.first_names", "people.last_names"), joins: { producer: :person } },
    net: "(SELECT SUM(purchases.net_weight) FROM purchases WHERE purchases.invoice_id = invoices.id)",
    # QQ = net ÷ 125: the same order as the net weight.
    quintals: "(SELECT SUM(purchases.net_weight) FROM purchases WHERE purchases.invoice_id = invoices.id)",
    total: "(SELECT SUM(purchases.total) FROM purchases WHERE purchases.invoice_id = invoices.id)",
    status: "invoices.payment_status"
  }.freeze
  sorts(**SORTS)

  def apply(scope)
    scope = scope.where(issued_on: from..) if from
    scope = scope.where(issued_on: ..to) if to
    scope = search(scope) if q
    # The season of its purchases (an invoice groups purchases of one producer).
    scope = scope.where(id: Purchase.where(season_year:).select(:invoice_id)) if season_year
    scope = scope.where(id: Purchase.where(zone_id:).select(:invoice_id)) if zone_id
    scope = scope.with_payment_status(payment_status) if payment_status
    # Paid (at least in part) that way.
    scope = scope.where(id: InvoicePayment.where(payment_method:).select(:invoice_id)) if payment_method
    scope.includes(:purchases, :payments, producer: :person).newest_first
  end

  private
    # By producer name, DNI/RTN, or invoice number ("0012" or "12").
    def search(scope)
      by_producer = scope.where(producer_id: Producer.joins(:person).merge(Person.search(q)).select(:id))
      q.match?(/\A\d+\z/) ? by_producer.or(scope.where(number: q.to_i)) : by_producer
    end
end
