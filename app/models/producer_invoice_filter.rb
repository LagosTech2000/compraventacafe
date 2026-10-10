# Invoices tab of a producer.
class ProducerInvoiceFilter < ListFilter
  field :payment_status, :choice, in: Invoice::PAYMENT_STATUSES

  def apply(scope)
    scope = scope.where(payment_status:) if payment_status
    scope.includes(:purchases, producer: :person).newest_first
  end
end
