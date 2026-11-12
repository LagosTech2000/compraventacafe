# A purchase of a supply into the inventory (Fernando, 2026-11-12): how
# much came in and what it cost. Saving it registers by itself an
# investment of Control financiero for that money (its category, account
# and method chosen here); removing it removes that investment. The
# investment is not edited apart: the entry is removed and registered
# again. Removed only while the loans do not need its quantity.
class SupplyEntry < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales, :finance, :loans

  belongs_to :supply
  belongs_to :expense, autosave: true
  belongs_to :created_by, class_name: "User"

  # The investment's own data, asked by the entry's form.
  attr_accessor :finance_category_id, :money_account_id, :payment_method

  normalizes :payee, :receipt_number, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :quantity, numericality: { greater_than: 0, less_than: 100_000 }
  validates :amount, numericality: { greater_than: 0, less_than: Expense::MAX_AMOUNT }
  validates :received_on, presence: true
  validates :payee, :receipt_number, length: { maximum: 120 }
  validates :observations, length: { maximum: 500 }
  validate :supply_active, on: :create
  validate :investment_valid, on: :create

  before_validation :build_investment, on: :create
  before_destroy :still_covers_loans, prepend: true
  # Loaded again: the one in memory still sees this entry and would refuse.
  after_destroy { Expense.find(expense_id).destroy! }

  scope :newest_first, -> { order(received_on: :desc, id: :desc) }

  def audit_label = "#{supply&.name} × #{quantity}"
  def unit_cost = quantity.to_d.positive? ? (amount / quantity).round(4) : nil

  private
    def build_investment
      return unless supply

      self.expense = Expense.new(kind: "investment", finance_category_id:, money_account_id:, payment_method:,
                                 spent_on: received_on, amount:, payee:, receipt_number:, created_by:,
                                 description: I18n.t("sales.supply_entries.investment", supply: supply.name,
                                                                                       quantity: ActiveSupport::NumberHelper.number_to_rounded(quantity.to_d, precision: 2, strip_insignificant_zeros: true),
                                                                                       unit: supply.unit))
    end

    # The investment's errors (category, account, method) show on the entry.
    def investment_valid
      return if expense.nil? || expense.valid?

      expense.errors.each do |error|
        attribute = { category: :finance_category_id, money_account: :money_account_id }.fetch(error.attribute, error.attribute)
        attribute = :base unless respond_to?(attribute)
        errors.add(attribute, error.message)
      end
    end

    def supply_active
      errors.add(:supply, :inactive) if supply && !supply.active?
    end

    def still_covers_loans
      return if SupplyStock.available(supply_id) - quantity >= 0

      errors.add(:base, :lent)
      throw :abort
    end
end
