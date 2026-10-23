# One print of a private document (PrivateDocument) for a loan of a
# person (Fernando, 2026-10-22; per loan since 2026-10-23): who printed
# it, when, and the document exactly as it printed. Each loan counts its
# prints per document; admins see the latest ones with their dates and
# users. The loan may be empty only for prints of before, or of a loan
# removed later.
class PrivateDocumentPrint < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :loans

  # The latest prints an admin sees beside a document's counter.
  HISTORY_SIZE = 10

  # The printed text is kept whole here; the log says who, what and when.
  self.audit_skipped_attributes = %w[body]

  belongs_to :private_document
  belongs_to :person
  belongs_to :loan, optional: true
  belongs_to :user

  validates :body, presence: true, unless: -> { private_document&.blank_body? }
  validate :document_has_text, :loan_of_the_person

  before_validation :fill_body, on: :create

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # How many times each document printed with each loan:
  # { [loan_id, document_id] => n }.
  def self.counts_by_loan(loans)
    where(loan: loans).group(:loan_id, :private_document_id).count
  end

  # The latest prints of each document with each loan, with their users:
  # { [loan_id, document_id] => [print, …] }, at most HISTORY_SIZE each.
  def self.history_by_loan(loans)
    ranked = where(loan: loans).select("private_document_prints.*, row_number() OVER " \
                                       "(PARTITION BY loan_id, private_document_id ORDER BY created_at DESC, id DESC) AS position")
    from(ranked, :private_document_prints).where("position <= ?", HISTORY_SIZE)
      .includes(:user).newest_first.group_by { |print| [ print.loan_id, print.private_document_id ] }
  end

  def audit_label
    "#{private_document.name} · #{person.full_name}"
  end

  private
    def fill_body
      return unless private_document && person

      self.body = private_document.filled_body(person:, loan:) unless private_document.blank_body?
    end

    def document_has_text
      errors.add(:base, :document_blank) if private_document&.blank_body?
    end

    def loan_of_the_person
      errors.add(:loan, :not_of_the_person) if loan && loan.person_id != person_id
    end
end
