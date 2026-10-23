# The private documents (the promissory note and the loan contract) with
# how many times each one printed for each loan, for a page that lists
# loans with their print buttons (the credit account, a loan's page).
# With history: true (admins), the latest prints of each too.
class LoanDocumentPrints
  attr_reader :documents

  def initialize(loans, history: false)
    ids = loans.map(&:id)
    @documents = PrivateDocument.ordered
    @counts = PrivateDocumentPrint.counts_by_loan(ids)
    @history = history ? PrivateDocumentPrint.history_by_loan(ids) : {}
  end

  def count(loan, document) = @counts.fetch([ loan.id, document.id ], 0)

  def history(loan, document) = @history.fetch([ loan.id, document.id ], [])
end
