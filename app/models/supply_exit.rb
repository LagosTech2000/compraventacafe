# Supplies that leave the inventory without a loan (Fernando, 2026-11-14:
# «que se pueda registrar una salida de inventario, como que lo vendan por
# aparte»), for one of two reasons:
# - sale: sold to a person of the system, quantity × price; the money comes
#   into an account (MoneyMovements «supply_sales», Ingresos).
# - business_use: the business uses it (fincas, bodega); no money.
# One or several supplies (lines, Fernando, 2026-11-16), as an entry. It
# takes from what is in the warehouse (never more, adding the lines of the
# same supply) and from what is left to lend. Registered or removed, never
# edited.
class SupplyExit < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  include DayLock
  locks_day :exited_on, free: %w[person_id]
  live_updates :sales, :finance

  KINDS = %w[sale business_use].freeze
  MAX_QUANTITY = 100_000

  belongs_to :person, optional: true
  belongs_to :money_account, optional: true
  belongs_to :created_by, class_name: "User"
  has_many :lines, -> { order(:id) }, class_name: "SupplyExitLine", dependent: :destroy, inverse_of: :supply_exit
  has_many :supplies, through: :lines
  accepts_nested_attributes_for :lines, allow_destroy: true, reject_if: :blank_line?

  normalizes :observations, with: FieldFormats::STRIP

  validates :kind, inclusion: { in: KINDS }
  validates :exited_on, presence: true
  validate :lines_present
  validates :observations, length: { maximum: 500 }
  with_options if: :sale? do
    validates :person, :money_account, presence: true
    validates :amount, numericality: { greater_than: 0, less_than: Expense::MAX_AMOUNT }, if: -> { kept_lines.any? && kept_lines.all?(&:unit_price) }
    validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  end
  validate :in_warehouse, on: :create
  validate { errors.add(:money_account, :inactive) if will_save_change_to_money_account_id? && money_account && !money_account.active? }

  before_validation :settle_kind

  scope :newest_first, -> { order(exited_on: :desc, id: :desc) }
  scope :sales, -> { where(kind: "sale") }

  def sale? = kind == "sale"
  def human_kind = self.class.human_attribute_name("kind/#{kind}")
  def human_payment_method = payment_method && Invoice.human_attribute_name("payment_method/#{payment_method}")

  def kept_lines = lines.reject(&:marked_for_destruction?)

  # «Urea × 3 saco, Fungicida × 5 litro».
  def summary = kept_lines.map(&:summary).join(", ")

  def audit_label = "#{human_kind} · #{summary}"

  private
    def blank_line?(attributes)
      attributes["id"].blank? && attributes.values_at("supply_id", "quantity").all?(&:blank?)
    end

    def lines_present
      errors.add(:lines, :blank) if kept_lines.empty?
    end

    # A use by the business moves no money: it keeps none of a sale's data.
    def settle_kind
      if sale?
        kept_lines.each { it.amount = (it.quantity.to_d * it.unit_price.to_d).round(2) if it.quantity && it.unit_price }
        self.amount = kept_lines.sum { it.amount.to_d }
      else
        self.person = self.money_account = nil
        self.amount = self.payment_method = nil
        kept_lines.each { it.unit_price = it.amount = nil }
      end
    end

    # Never more than is in the warehouse, adding the lines of each supply.
    def in_warehouse
      kept_lines.select(&:supply).group_by(&:supply).each do |supply, lines|
        quantity = lines.sum { it.quantity.to_d }
        next unless quantity.positive?

        there = SupplyStock.in_warehouse(supply.id)
        next if quantity <= there

        there_text = ActiveSupport::NumberHelper.number_to_rounded(there, precision: 2, strip_insignificant_zeros: true, delimiter: ",")
        errors.add(:base, :not_in_warehouse, supply: supply.name, available: "#{there_text} #{supply.unit}")
      end
    end
end
