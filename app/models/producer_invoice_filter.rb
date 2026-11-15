# Invoices tab of a producer.
class ProducerInvoiceFilter < ListFilter
  field :payment_status, :choice, in: Invoice::LIST_STATUSES

  sorts(**InvoiceFilter::SORTS)

  def apply(scope)
    scope = payment_status ? scope.with_payment_status(payment_status) : scope.active
    scope.includes(:purchases, :payments, producer: :person).newest_first
  end
end
