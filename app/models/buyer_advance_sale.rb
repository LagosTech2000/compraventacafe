# An advance applied to a sale (Fernando, 2026-11-16: «se pueden crear
# anticipos sin asociarlos a una venta, por % igual que las facturas;
# pueden pertenecer a varias ventas»): a % of the advance, its amount
# (amount × %, the rest of the balance when it takes all that is left), on
# a day. It collects that much from the sale «con anticipo» (its
# SalePayment, which moves no money), never over what the sale is due.
# Any sale: a bank's advance pays any buyer's sales. Applied or removed,
# never edited; removing it removes that collection.
class BuyerAdvanceSale < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  live_updates :sales

  belongs_to :buyer_advance, inverse_of: :applications
  belongs_to :sale
  belongs_to :created_by, class_name: "User"
  has_one :payment, class_name: "SalePayment", dependent: :destroy, inverse_of: :buyer_advance_sale

  validates :applied_on, presence: true
  validates :percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :amount, numericality: { greater_than: 0 }
  validates :sale_id, uniqueness: { scope: :buyer_advance_id }
  validate :within_advance, :within_sale, :not_before_advance, on: :create

  before_validation :settle_amount, on: :create
  after_create :collect
  after_commit :refresh_advance

  def audit_label = "#{buyer_advance&.audit_label} → #{I18n.t("sales.sales.show.title", number: sale&.display_number)}"
  def percent_text = ActiveSupport::NumberHelper.number_to_percentage(percent, precision: 2, strip_insignificant_zeros: true)

  private
    # Its share of the advance; all of what is left when it takes the rest.
    def settle_amount
      return unless buyer_advance && percent.to_d.positive?

      self.amount = if percent.to_d >= buyer_advance.free_percent
        buyer_advance.balance
      else
        (buyer_advance.amount * percent.to_d / 100).round(2)
      end
    end

    def within_advance
      return unless buyer_advance && percent.to_d.positive?

      free = buyer_advance.free_percent
      errors.add(:percent, :over_advance, free: ActiveSupport::NumberHelper.number_to_percentage(free, precision: 2, strip_insignificant_zeros: true)) if percent.to_d > free
    end

    def within_sale
      return unless sale && amount.to_d.positive?

      errors.add(:base, :sale_voided) if sale.voided?
      errors.add(:amount, :over_sale, balance: ActiveSupport::NumberHelper.number_to_currency(sale.balance_due)) if amount > sale.balance_due
    end

    def not_before_advance
      errors.add(:applied_on, :before_advance) if buyer_advance && applied_on && applied_on < buyer_advance.received_on
    end

    # The collection «con anticipo»: its errors (a date before the sale or
    # its last collection) stop the application.
    def collect
      collection = SalePayment.new(sale:, buyer_advance_sale: self, amount:, paid_on: applied_on, payment_method: SalePayment::ADVANCE,
                                   created_by:, observations: I18n.t("sales.buyer_advance_sales.collection", number: buyer_advance.display_number))
      return if collection.save

      collection.errors.each { |error| errors.add(:base, error.full_message) }
      raise ActiveRecord::RecordInvalid, self
    end

    def refresh_advance
      BuyerAdvance.find_by(id: buyer_advance_id)&.refresh_status!
    end
end
