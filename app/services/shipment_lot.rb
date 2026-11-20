# «¿Qué café lleva?» (Fernando, 2026-11-18: they spent a lot of work
# choosing invoices by percent): a shipment picks the invoices it carries,
# and their lot is made on its own, with what is left of each one (its
# percent left, CoffeeBatchInvoice's rules), or the percent written for
# it (Fernando, 2026-11-20: «una casilla de % por factura»), never more
# than what is left. The lots screen stays for the special cases.
class ShipmentLot
  # An invoice a shipment may carry: all its purchases of one coffee state
  # and in one warehouse, with a share left out of the lots.
  Option = Data.define(:invoice, :coffee_state, :warehouse_id, :entered_at, :percent_left, :gross, :net, :invoice_gross, :invoice_net) do
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

    gross = purchases.sum { it.gross_weight.to_d }
    net = purchases.sum { it.net_weight.to_d }
    Option.new(invoice:, coffee_state: states.first, warehouse_id: warehouses.first, entered_at: purchases.map(&:purchased_at).max,
               percent_left: left, gross: (gross * left / 100).round(2), net: (net * left / 100).round(2), invoice_gross: gross, invoice_net: net)
  end

  # `percents`: { invoice id => percent } written in the form; an invoice
  # without one takes what is left of it.
  def initialize(shipment:, invoice_ids:, invoices:, user:, percents: {})
    @shipment = shipment
    @invoice_ids = Array(invoice_ids).compact_blank.map(&:to_i).uniq
    @percents = percents.to_h.to_h { |id, percent| [ id.to_i, percent.to_s.strip ] }.reject { |_, percent| percent.empty? }
    @invoices = invoices
    @user = user
  end

  # The new lot with the chosen invoices, or nil with the shipment's errors.
  # Inside the shipment's transaction: when it is not saved, neither is the lot.
  def call
    chosen = self.class.options(@invoices.where(id: @invoice_ids))
                 .select { it.coffee_state == @shipment.coffee_state && it.warehouse_id == @shipment.warehouse_id }
    return fail_with(:lot_invoices_unavailable) if chosen.size != @invoice_ids.size

    shares = chosen.to_h { [ it, percent_for(it) ] }
    wrong = shares.find { |option, percent| percent.nil? || percent <= 0 || percent > option.percent_left }
    return fail_with(:base, I18n.t("sales.shipments.coffee_field.percent_error", number: wrong.first.invoice.display_number,
                                                                                left: ActiveSupport::NumberHelper.number_to_rounded(wrong.first.percent_left, precision: 4, strip_insignificant_zeros: true))) if wrong

    gross = shares.sum { |option, percent| option.invoice_gross * percent / 100 }
    batch = CoffeeBatch.create!(coffee_state: @shipment.coffee_state, warehouse_id: @shipment.warehouse_id, created_by: @user,
                                batched_on: @shipment.departed_at&.to_date || Time.zone.today, gross_limit: (gross + 0.000_01).ceil(2) + 0.01,
                                observations: I18n.t("sales.shipments.coffee_field.lot_observations"))
    shares.each { |option, percent| batch.batch_invoices.create!(invoice: option.invoice, percent:, created_by: @user) }
    batch
  rescue ActiveRecord::RecordInvalid => error
    fail_with(:base, I18n.t("sales.shipments.coffee_field.lot_error", message: error.record.errors.full_messages.to_sentence))
  end

  private
    # The percent written for it (at most 4 decimals), or what is left.
    def percent_for(option)
      written = @percents[option.invoice.id]
      return option.percent_left unless written

      BigDecimal(written.delete(",")).round(4)
    rescue ArgumentError
      nil
    end

    def fail_with(key, message = nil)
      message ? @shipment.errors.add(:base, message) : @shipment.errors.add(:base, key)
      nil
    end
end
