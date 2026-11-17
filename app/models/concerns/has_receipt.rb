# The photo or PDF of a receipt (ExpenseReceipt), optional: expenses
# (Fernando, 2026-10-23) and a shipment's costs (Fernando, 2026-11-16). The
# form sends `receipt_upload` (a photo the browser already shrank, or a
# PDF) and `remove_receipt`.
module HasReceipt
  extend ActiveSupport::Concern

  included do
    has_one :receipt, class_name: "ExpenseReceipt", dependent: :destroy, autosave: true
    # The receipt without its bytes, to show it in lists.
    has_one :receipt_info, -> { select(ExpenseReceipt.column_names - %w[data]) }, class_name: "ExpenseReceipt"

    attr_reader :receipt_upload, :remove_receipt

    validate :receipt_upload_is_valid
  end

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
    def receipt_upload_is_valid
      return unless @receipt_bytes

      if @receipt_bytes.bytesize > ExpenseReceipt::MAX_SIZE
        errors.add(:receipt_upload, :too_big, size: ActiveSupport::NumberHelper.number_to_human_size(ExpenseReceipt::MAX_SIZE))
      elsif ExpenseReceipt.content_type_of(@receipt_bytes).nil?
        errors.add(:receipt_upload, :not_a_receipt)
      end
    end
end
