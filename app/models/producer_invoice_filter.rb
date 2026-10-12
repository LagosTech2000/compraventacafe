# Invoices tab of a producer.
class ProducerInvoiceFilter < ListFilter
  field :payment_status, :choice, in: Invoice::FILTER_STATUSES

  def apply(scope)
    scope = scope.with_payment_status(payment_status) if payment_status
    scope.includes(:purchases, :payments, producer: :person).newest_first
  end
end
