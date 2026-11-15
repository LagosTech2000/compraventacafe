# A purchase of supplies into the inventory (Fernando, 2026-11-12): one
# invoice of the supplier, with one or more supplies (lines, Fernando,
# 2026-11-13), and optionally the photo or PDF of that invoice. Saving it
# registers by itself one investment of Control financiero for its total
# (its category, account and method chosen here; the invoice uploaded is
# the investment's receipt); removing it removes that investment. The
# investment is not edited apart: the entry is removed and registered
# again. Removed only while what it brought was not handed out yet (the
# supplies delivered on loans stay covered).
class SupplyEntry < ApplicationRecord
  include Auditable
  include OwnedRecord
  include LiveUpdates
  live_updates :sales, :finance, :loans

  belongs_to :expense, autosave: true
  belongs_to :created_by, class_name: "User"
  has_many :lines, -> { order(:id) }, class_name: "SupplyEntryLine", dependent: :destroy, inverse_of: :supply_entry
  has_many :supplies, through: :lines
  accepts_nested_attributes_for :lines, allow_destroy: true, reject_if: :blank_line?

  # The investment's own data, asked by the entry's form, and the invoice.
  attr_accessor :finance_category_id, :money_account_id, :payment_method, :receipt_upload

  normalizes :payee, :receipt_number, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :received_on, presence: true
  validates :payee, :receipt_number, length: { maximum: 120 }
  validates :observations, length: { maximum: 500 }
  validate :lines_present
  validates :amount, numericality: { greater_than: 0, less_than: Expense::MAX_AMOUNT }, if: :kept_lines_present?
  validate :investment_valid, on: :create

  before_validation :sum_lines
  before_validation :build_investment, on: :create
  before_destroy :still_in_warehouse, prepend: true
  # Loaded again: the one in memory still sees this entry and would refuse.
  after_destroy { Expense.find(expense_id).destroy! }

  scope :newest_first, -> { order(received_on: :desc, id: :desc) }

  def kept_lines = lines.reject(&:marked_for_destruction?)

  def audit_label = "#{self.class.model_name.human} #{id} · #{kept_lines.map { it.supply&.name }.compact.to_sentence}"

  # «Abono 10 sacos, Fungicida 5 litros».
  def summary
    kept_lines.map do |line|
      quantity = ActiveSupport::NumberHelper.number_to_rounded(line.quantity.to_d, precision: 2, strip_insignificant_zeros: true)
      I18n.t("sales.supply_entries.line", supply: line.supply&.name, quantity:, unit: line.supply&.unit)
    end.join(", ")
  end

  private
    def blank_line?(attributes)
      attributes["id"].blank? && attributes.values_at("supply_id", "quantity", "amount").all?(&:blank?)
    end

    def kept_lines_present? = kept_lines.any?

    def lines_present
      errors.add(:lines, :blank) unless kept_lines_present?
    end

    def sum_lines
      self.amount = kept_lines.sum { it.amount.to_d } if kept_lines_present?
    end

    def build_investment
      return unless kept_lines_present?

      self.expense = Expense.new(kind: "investment", finance_category_id:, money_account_id:, payment_method:,
                                 spent_on: received_on, amount:, payee:, receipt_number:, created_by:, receipt_upload:,
                                 description: I18n.t("sales.supply_entries.investment", supplies: summary).truncate(200))
    end

    # The investment's errors (category, account, method, invoice) show on the entry.
    def investment_valid
      return if expense.nil? || expense.valid?

      expense.errors.each do |error|
        attribute = { category: :finance_category_id, money_account: :money_account_id }.fetch(error.attribute, error.attribute)
        attribute = :base unless respond_to?(attribute)
        errors.add(attribute, error.message)
      end
    end

    # What it brought and was already handed out on loans stays covered.
    def still_in_warehouse
      short = lines.select { |line| SupplyStock.in_warehouse(line.supply_id) - line.quantity < 0 }
      return if short.empty?

      errors.add(:base, :delivered, supplies: short.map { it.supply.name }.to_sentence)
      throw :abort
    end
end
