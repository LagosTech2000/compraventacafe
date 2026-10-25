# Groups shipments of one buyer, already weighed at destination and in no
# sale, into a new sale (like InvoiceIssuer with purchases). All of one
# coffee state: a sale has one price. It is charged on the buyer's net
# weight; each line keeps its weights and amount.
#
# Part of it can be taken off the buyer's advances (`advance_amount`, a
# collection «con anticipo», Fernando, 2026-10-25), and what is left can be
# collected on the spot, in full ("paid", contado) or in part ("partial",
# with the amount). All of it is saved or none.
class SaleIssuer
  Result = Data.define(:sale) do
    def success? = sale.persisted? && sale.errors.none?
  end

  PAYMENT_CHOICES = Sale::PAYMENT_STATUSES

  def initialize(buyer:, shipment_ids:, user:, sale: {}, payment_status: nil, payment_method: nil, paid_on: nil, amount: nil, money_account_id: nil,
                 advance_amount: nil)
    @buyer = buyer
    @shipment_ids = Array(shipment_ids).compact_blank.map(&:to_i)
    @user = user
    @attributes = sale.to_h.symbolize_keys.slice(:sold_on, :price_unit, :unit_price, :buyer_document_number, :observations)
    @payment_status = payment_status.presence_in(PAYMENT_CHOICES) || "pending"
    @payment = { payment_method: payment_method.presence, paid_on: paid_on.presence || @attributes[:sold_on].presence || Time.zone.today,
                 amount: amount.presence, money_account_id: money_account_id.presence }
    @advance_amount = advance_amount.to_d
  end

  def call
    sale = @buyer.sales.build(created_by: @user, payment_status: "pending", sold_on: Time.zone.today, **@attributes.compact_blank)

    Sale.transaction(requires_new: true) do
      # Locking the rows keeps two people from selling the same shipment.
      shipments = @buyer.shipments.unsold.where(id: @shipment_ids).lock.to_a

      if @shipment_ids.empty?
        sale.errors.add(:lines, :blank)
      elsif shipments.size != @shipment_ids.uniq.size
        sale.errors.add(:lines, :unavailable)
      elsif shipments.map(&:coffee_state).uniq.many?
        sale.errors.add(:lines, :mixed_states)
      else
        build_lines(sale, shipments)
        raise ActiveRecord::Rollback unless sale.save && take_advance(sale) && collect(sale)
      end
    end

    Result.new(sale)
  end

  private
    def build_lines(sale, shipments)
      sale.coffee_state = shipments.first.coffee_state
      price_ok = sale.unit_price.to_d.positive? && sale.price_unit.in?(Sale::PRICE_UNITS)
      shipments.sort_by(&:number).each do |shipment|
        amount = price_ok ? Sale.amount_for(shipment.destination_net_weight, unit_price: sale.unit_price, price_unit: sale.price_unit) : 0
        sale.lines.build(shipment:, net_weight: shipment.destination_net_weight, origin_net_weight: shipment.origin_net_weight, amount:)
      end
      sale.net_weight = shipments.sum(&:destination_net_weight)
      sale.origin_net_weight = shipments.sum(&:origin_net_weight)
      # On the whole weight, so rounding per line never moves a cent.
      sale.total = price_ok ? Sale.amount_for(sale.net_weight, unit_price: sale.unit_price, price_unit: sale.price_unit) : 0
    end

    # What is taken off the buyer's advances, on the sale's day.
    def take_advance(sale)
      return true unless @advance_amount.positive?

      record_payment(sale, amount: @advance_amount, paid_on: sale.sold_on, payment_method: SalePayment::ADVANCE, money_account_id: nil)
    end

    # The payment made when selling, if any, on what the advance left.
    # Its errors go on the sale.
    def collect(sale)
      return true if @payment_status == "pending"

      balance = sale.balance_due
      return true if @payment_status == "paid" && balance.zero?

      amount = @payment_status == "paid" ? balance : @payment[:amount]
      if @payment_status == "partial" && amount.to_d >= balance
        sale.errors.add(:base, :partial_not_less)
        return false
      end

      record_payment(sale, amount:, paid_on: @payment[:paid_on], payment_method: @payment[:payment_method],
                           money_account_id: @payment[:money_account_id])
    end

    def record_payment(sale, **attributes)
      payment = sale.payments.create(**attributes, created_by: @user)
      payment.errors.each { |error| sale.errors.add(:base, error.full_message) }
      payment.persisted?
    end
end
