# Supplies that leave the inventory without a loan (Fernando, 2026-11-14:
# «que se pueda registrar una salida de inventario, como que lo vendan por
# aparte»), for one of two reasons:
# - sale: sold to a person of the system, quantity × price; the money comes
#   into an account (MoneyMovements «supply_sales», Ingresos).
# - business_use: the business uses it (fincas, bodega); no money.
# It takes from what is in the warehouse (never more) and from what is left
# to lend. Registered or removed, never edited.
class SupplyExit < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  live_updates :sales, :finance

  KINDS = %w[sale business_use].freeze
  MAX_QUANTITY = 100_000

  belongs_to :supply
  belongs_to :person, optional: true
  belongs_to :money_account, optional: true
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :kind, inclusion: { in: KINDS }
  validates :exited_on, presence: true
  validates :quantity, numericality: { greater_than: 0, less_than: MAX_QUANTITY }
  validates :observations, length: { maximum: 500 }
  with_options if: :sale? do
    validates :person, :money_account, presence: true
    validates :unit_price, numericality: { greater_than: 0, less_than: Supply::MAX_PRICE }
    validates :amount, numericality: { greater_than: 0, less_than: Expense::MAX_AMOUNT }, if: :unit_price
    validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  end
  validate :supply_active, on: :create
  validate :in_warehouse, on: :create
  validate { errors.add(:money_account, :inactive) if will_save_change_to_money_account_id? && money_account && !money_account.active? }

  before_validation :settle_kind

  scope :newest_first, -> { order(exited_on: :desc, id: :desc) }
  scope :sales, -> { where(kind: "sale") }

  def sale? = kind == "sale"
  def human_kind = self.class.human_attribute_name("kind/#{kind}")
  def human_payment_method = payment_method && Invoice.human_attribute_name("payment_method/#{payment_method}")

  # «Abono 10 sacos».
  def summary
    quantity_text = ActiveSupport::NumberHelper.number_to_rounded(quantity.to_d, precision: 2, strip_insignificant_zeros: true, delimiter: ",")
    I18n.t("sales.supply_entries.line", supply: supply&.name, quantity: quantity_text, unit: supply&.unit)
  end

  def audit_label = "#{human_kind} · #{summary}"

  private
    # A use by the business moves no money: it keeps none of a sale's data.
    def settle_kind
      if sale?
        self.amount = (quantity.to_d * unit_price.to_d).round(2) if quantity && unit_price
      else
        self.person = self.money_account = nil
        self.unit_price = self.amount = self.payment_method = nil
      end
    end

    def supply_active
      errors.add(:supply, :inactive) if supply && !supply.active?
    end

    def in_warehouse
      return unless supply && quantity.to_d.positive?

      there = SupplyStock.in_warehouse(supply_id)
      return if quantity.to_d <= there

      there_text = ActiveSupport::NumberHelper.number_to_rounded(there, precision: 2, strip_insignificant_zeros: true, delimiter: ",")
      errors.add(:quantity, :not_in_warehouse, available: "#{there_text} #{supply.unit}")
    end
end
