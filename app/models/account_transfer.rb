# Money moved from one account to another (cash deposited in the bank,
# cash taken out): it leaves one and enters the other, and is neither an
# expense nor an income of the business.
class AccountTransfer < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  belongs_to :from_account, class_name: "MoneyAccount"
  belongs_to :to_account, class_name: "MoneyAccount"
  belongs_to :created_by, class_name: "User"

  normalizes :observations, with: FieldFormats::STRIP

  validates :transferred_on, presence: true
  validates :amount, numericality: { greater_than: 0, less_than: Expense::MAX_AMOUNT }
  validates :observations, length: { maximum: 500 }
  validate { errors.add(:to_account, :same_account) if from_account_id && from_account_id == to_account_id }
  validate do
    [ :from_account, :to_account ].each do |name|
      account = public_send(name)
      errors.add(name, :inactive) if account && !account.active? && will_save_change_to_attribute?("#{name}_id")
    end
  end

  scope :newest_first, -> { order(transferred_on: :desc, id: :desc) }

  def audit_label = "#{from_account&.name} → #{to_account&.name}"
end
