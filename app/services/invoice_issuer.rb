# Groups a producer's uninvoiced purchases into a new invoice.
class InvoiceIssuer
  Result = Data.define(:invoice) do
    def success? = invoice.persisted?
  end

  def initialize(producer:, purchase_ids:, user:, payment_status:, payment_method: nil, paid_on: nil)
    @producer = producer
    @purchase_ids = Array(purchase_ids).compact_blank
    @user = user
    @attributes = { payment_status:, payment_method: payment_method.presence, paid_on: paid_on.presence }
  end

  def call
    invoice = @producer.invoices.build(created_by: @user, issued_on: Time.zone.today, **@attributes)
    invoice.paid_on ||= invoice.issued_on if invoice.paid?

    Invoice.transaction do
      # Locking the rows keeps two people from invoicing the same purchase.
      purchases = @producer.purchases.uninvoiced.where(id: @purchase_ids).lock.to_a

      if purchases.size == @purchase_ids.uniq.size
        invoice.purchases = purchases
        invoice.save
      else
        invoice.errors.add(:purchases, :unavailable)
      end
    end

    Result.new(invoice)
  end
end
