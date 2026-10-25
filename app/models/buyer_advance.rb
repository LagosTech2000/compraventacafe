# An advance a buyer gives the business, paid back with coffee, without
# interest (Fernando, 2026-10-25). The money comes into an account on its
# day (MoneyMovements: buyer_advances). The buyer's advance balance
# (Buyer#advance_balance) goes down with each collection «con anticipo»
# taken off a sale. Never edited; removed only while its money was not
# taken off any sale yet.
class BuyerAdvance < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  belongs_to :buyer
  belongs_to :money_account
  belongs_to :created_by, class_name: "User"

  normalizes :document_number, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :received_on, presence: true
  validates :amount, numericality: { greater_than: 0, less_than: 100_000_000 }
  validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  validates :document_number, length: { maximum: 60 }
  validates :observations, length: { maximum: 500 }
  validate :money_account_active, if: :will_save_change_to_money_account_id?

  before_destroy :ensure_not_used, prepend: true

  scope :newest_first, -> { order(received_on: :desc, id: :desc) }

  def display_number = format("%04d", id)
  def audit_label = "#{self.class.model_name.human} #{display_number} · #{buyer&.name}"
  def human_payment_method = Invoice.human_attribute_name("payment_method/#{payment_method}")

  # Removing it would not leave the buyer with more taken off than given.
  def removable? = buyer.advance_balance >= amount

  private
    def money_account_active
      errors.add(:money_account, :inactive) if money_account && !money_account.active?
    end

    def ensure_not_used
      return if removable?

      errors.add(:base, :used)
      throw :abort
    end
end
