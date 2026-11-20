# «¿Qué café lleva?» (Fernando, 2026-11-18: they spent a lot of work
# choosing invoices by percent): a shipment picks the invoices it carries,
# and their lot is made on its own, with what is left of each one (its
# percent left, CoffeeBatchInvoice's rules). The lots screen stays for the
# special cases.
class ShipmentLot
  # An invoice a shipment may carry: all its purchases of one coffee state
  # and in one warehouse, with a share left out of the lots.
  Option = Data.define(:invoice, :coffee_state, :warehouse_id, :entered_at, :percent_left, :gross, :net) do
    def producer_name = invoice.producer.full_name
  end

  # The invoices of the scope (the user's) a shipment may carry, of every
  # state and warehouse (the form shows the ones of its own), the oldest
  # purchase first.
  def self.options(invoices)
    full = CoffeeBatchInvoice.group(:invoice_id).having("SUM(percent) >= 100").select(:invoice_id)
    candidates = invoices.active.where.not(id: full).includes(:purchases, producer: :person).to_a
    used = CoffeeBatchInvoice.used_by_invoice(candidates.map(&:id))
    candidates.filter_map { |invoice| option(invoice, used.fetch(invoice.id, 0).to_d) }.sort_by { [ it.entered_at, it.invoice.id ] }
  end

  def self.option(invoice, used)
    purchases = invoice.purchases.reject(&:voided?)
    states = purchases.map(&:coffee_state).uniq
    warehouses = purchases.map(&:warehouse_id).uniq
    left = 100 - used
    return unless states.one? && warehouses.one? && left.positive?

    share = ->(attribute) { (purchases.sum { it.public_send(attribute).to_d } * left / 100).round(2) }
    Option.new(invoice:, coffee_state: states.first, warehouse_id: warehouses.first, entered_at: purchases.map(&:purchased_at).max,
               percent_left: left, gross: share.(:gross_weight), net: share.(:net_weight))
  end

  def initialize(shipment:, invoice_ids:, invoices:, user:)
    @shipment = shipment
    @invoice_ids = Array(invoice_ids).compact_blank.map(&:to_i).uniq
    @invoices = invoices
    @user = user
  end

  # The new lot with the chosen invoices, or nil with the shipment's errors.
  # Inside the shipment's transaction: when it is not saved, neither is the lot.
  def call
    chosen = self.class.options(@invoices.where(id: @invoice_ids))
                 .select { it.coffee_state == @shipment.coffee_state && it.warehouse_id == @shipment.warehouse_id }
    return fail_with(:lot_invoices_unavailable) if chosen.size != @invoice_ids.size

    gross = chosen.sum(&:gross)
    batch = CoffeeBatch.create!(coffee_state: @shipment.coffee_state, warehouse_id: @shipment.warehouse_id, created_by: @user,
                                batched_on: @shipment.departed_at&.to_date || Time.zone.today, gross_limit: (gross + 0.000_01).ceil(2) + 0.01,
                                observations: I18n.t("sales.shipments.coffee_field.lot_observations"))
    chosen.each { batch.batch_invoices.create!(invoice: it.invoice, percent: it.percent_left, created_by: @user) }
    batch
  rescue ActiveRecord::RecordInvalid => error
    fail_with(:base, I18n.t("sales.shipments.coffee_field.lot_error", message: error.record.errors.full_messages.to_sentence))
  end

  private
    def fail_with(key, message = nil)
      message ? @shipment.errors.add(:base, message) : @shipment.errors.add(:base, key)
      nil
    end
end
