# Who did what to which record, and when. Written by Auditable and by the
# session controller; never updated or deleted by the application.
class AuditEvent < ApplicationRecord
  ACTIONS = %w[create update destroy sign_in sign_out sign_in_failed backup error rate_limited merge].freeze
  # Keep in sync with the models that include Auditable (a spec checks it).
  AUDITED_TYPES = %w[User Permission Person Client Collaborator Producer Zone Purchase Invoice InvoicePayment Loan LoanPayment Supply LoanSupply PurchaseWeighing Hauler HaulerPayment Farm ExpenseCategory Payroll PayrollRole PayrollMember PayrollAttendance HarvestEntry PayrollOvertime PayrollTask PayrollTaskParticipant PayrollPayment PayrollPaymentLine PayrollExpense SavedReport SiteSetting ProfilePhoto WebauthnCredential PrivateDocument PrivateDocumentPrint Buyer Shipment ShipmentWeighing Sale SaleLine SalePayment MoneyAccount FinanceCategory Expense ExpenseReceipt OtherIncome AccountTransfer Budget StaffRole StaffMember StaffPayment StaffAdvance StaffGoal StaffAttendance Carrier Truck BuyerAdvance CoffeeConversion CashCount].freeze
  FILTERED = "[FILTERED]".freeze

  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }

  # details: what else there is to know (an error's route, status, message…).
  def self.record!(action:, auditable: nil, label: nil, changeset: {}, details: {}, user: Current.user,
                   ip_address: Current.ip_address, request_id: Current.request_id)
    create!(
      action:, auditable_type: auditable&.class&.name, auditable_id: auditable&.id,
      auditable_label: (label || auditable&.audit_label).to_s.truncate(255),
      changeset:, details:, user:, user_email: user&.email_address,
      ip_address:, request_id:
    )
  end

  # Saved events cannot be changed or destroyed through Active Record.
  def readonly?
    persisted?
  end

  def human_action
    self.class.human_attribute_name("action/#{action}")
  end

  def human_auditable_type
    auditable_type && auditable_type.safe_constantize&.model_name&.human
  end
end
