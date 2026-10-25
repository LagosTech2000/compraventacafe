# The photo or PDF of an expense's receipt (Fernando, 2026-10-23: optional).
# Its bytes live in the database, as the profile photos'; served to who can
# see the expense (Finance::ExpenseReceiptsController). Only JPEG, PNG,
# WebP or PDF, checked by their content, up to 1 MB.
class ExpenseReceipt < ApplicationRecord
  include Auditable

  MAX_SIZE = 1.megabyte
  SIGNATURES = ProfilePhoto::SIGNATURES.merge("application/pdf" => ->(bytes) { bytes.start_with?("%PDF-".b) }).freeze

  self.audit_skipped_attributes = %w[data]

  belongs_to :expense

  validates :content_type, inclusion: { in: SIGNATURES.keys }
  validates :byte_size, numericality: { less_than_or_equal_to: MAX_SIZE }

  def self.content_type_of(bytes)
    SIGNATURES.find { |_, matches| matches.call(bytes) }&.first
  end

  def audit_label = I18n.t("finance.expense_receipts.audit_label", expense: expense&.description)
  def pdf? = content_type == "application/pdf"
  def version = updated_at.to_i
end
