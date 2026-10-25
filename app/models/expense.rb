# Money the business spends (Control financiero, Fernando, 2026-10-23): an
# expense of the day to day or an investment (vehicles, scales, land,
# machinery…), each with its category, who was paid, the account it came
# out of, its payment method and receipt number, and optionally the photo
# or PDF of the receipt (ExpenseReceipt).
class Expense < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :finance

  KINDS = FinanceCategory::KINDS
  MAX_AMOUNT = 100_000_000

  belongs_to :category, class_name: "FinanceCategory", foreign_key: :finance_category_id, inverse_of: :expenses
  belongs_to :money_account
  belongs_to :created_by, class_name: "User"
  has_one :receipt, class_name: "ExpenseReceipt", dependent: :destroy, autosave: true
  # The receipt without its bytes, to show it in lists.
  has_one :receipt_info, -> { select(ExpenseReceipt.column_names - %w[data]) }, class_name: "ExpenseReceipt"

  attr_reader :receipt_upload, :remove_receipt

  normalizes :payee, :description, :receipt_number, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP

  validates :kind, inclusion: { in: KINDS }
  validates :spent_on, presence: true
  validates :description, presence: true, length: { maximum: 200 }
  validates :payee, :receipt_number, length: { maximum: 120 }
  validates :amount, numericality: { greater_than: 0, less_than: MAX_AMOUNT }
  validates :payment_method, inclusion: { in: Invoice::PAYMENT_METHODS }
  validates :observations, length: { maximum: 500 }
  validate :category_fits, if: -> { will_save_change_to_finance_category_id? || will_save_change_to_kind? }
  validate :account_active, if: :will_save_change_to_money_account_id?
  validate :receipt_upload_is_valid

  scope :expenses, -> { where(kind: "expense") }
  scope :investments, -> { where(kind: "investment") }
  scope :newest_first, -> { order(spent_on: :desc, id: :desc) }

  def audit_label = "#{human_kind} · #{description}"
  def human_kind = self.class.human_attribute_name("kind/#{kind}")
  def human_payment_method = Invoice.human_attribute_name("payment_method/#{payment_method}")
  def investment? = kind == "investment"

  # The file the form sent (a photo, which the browser already shrank, or a PDF).
  def receipt_upload=(file)
    @receipt_upload = file
    return unless file.respond_to?(:read)

    @receipt_bytes = file.read.b
    type = ExpenseReceipt.content_type_of(@receipt_bytes)
    return unless type && @receipt_bytes.bytesize <= ExpenseReceipt::MAX_SIZE

    (receipt || build_receipt).assign_attributes(data: @receipt_bytes, content_type: type, byte_size: @receipt_bytes.bytesize,
                                                 filename: File.basename(file.original_filename.to_s).first(255).presence)
  end

  def remove_receipt=(value)
    @remove_receipt = value
    receipt&.mark_for_destruction if ActiveModel::Type::Boolean.new.cast(value) && !@receipt_bytes
  end

  private
    def category_fits
      return unless category

      errors.add(:category, :other_kind) if category.kind != kind
      errors.add(:category, :inactive) unless category.active?
    end

    def account_active
      errors.add(:money_account, :inactive) if money_account && !money_account.active?
    end

    def receipt_upload_is_valid
      return unless @receipt_bytes

      if @receipt_bytes.bytesize > ExpenseReceipt::MAX_SIZE
        errors.add(:receipt_upload, :too_big, size: ActiveSupport::NumberHelper.number_to_human_size(ExpenseReceipt::MAX_SIZE))
      elsif ExpenseReceipt.content_type_of(@receipt_bytes).nil?
        errors.add(:receipt_upload, :not_a_receipt)
      end
    end
end
