# Groups a producer's uninvoiced purchases into a new invoice. It can be
# paid on the spot: in full ("paid") or in part ("partial", with the amount
# paid now), as a first payment (InvoicePayment). All of it is saved or none.
class InvoiceIssuer
  Result = Data.define(:invoice) do
    # After a rollback the record can still look saved: its errors tell.
    def success? = invoice.persisted? && invoice.errors.none?
  end

  PAYMENT_CHOICES = Invoice::PAYMENT_STATUSES

  def initialize(producer:, purchase_ids:, user:, payment_status:, payment_method: nil, paid_on: nil, amount: nil)
    @producer = producer
    @purchase_ids = Array(purchase_ids).compact_blank
    @user = user
    @payment_status = payment_status.presence_in(PAYMENT_CHOICES) || "pending"
    @payment = { payment_method: payment_method.presence, paid_on: paid_on.presence || Time.zone.today, amount: amount.presence }
  end

  def call
    invoice = @producer.invoices.build(created_by: @user, issued_on: Time.zone.today, payment_status: "pending")

    # Its own savepoint: a rejected payment undoes the invoice even when this
    # runs inside another transaction (a bare Rollback there is ignored).
    Invoice.transaction(requires_new: true) do
      # Locking the rows keeps two people from invoicing the same purchase.
      purchases = @producer.purchases.uninvoiced.where(id: @purchase_ids).lock.to_a

      if purchases.size != @purchase_ids.uniq.size
        invoice.errors.add(:purchases, :unavailable)
      elsif invoice.update(purchases:) && !pay(invoice)
        raise ActiveRecord::Rollback
      end
    end

    Result.new(invoice)
  end

  private
    # The payment made when invoicing, if any. Its errors go on the invoice,
    # so the form shows them.
    def pay(invoice)
      # Pending, or nothing to pay (its loans took it all, so it is paid as it is).
      if @payment_status == "pending" || !invoice.amount_to_pay.positive?
        invoice.refresh_payment_status!
        return true
      end

      amount = @payment_status == "paid" ? invoice.amount_to_pay : @payment[:amount]
      if @payment_status == "partial" && amount.to_d >= invoice.amount_to_pay
        invoice.errors.add(:base, :partial_not_less)
        return false
      end

      payment = invoice.payments.create(amount:, paid_on: @payment[:paid_on], payment_method: @payment[:payment_method], created_by: @user)
      payment.errors.each { |error| invoice.errors.add(:base, error.full_message) }
      payment.persisted?
    end
end
