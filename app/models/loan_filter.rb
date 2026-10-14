class LoanFilter < ListFilter
  field :from, :date
  field :to, :date
  field :q, :text
  field :status, :choice, in: Loan::STATUSES
  field :kind, :choice, in: Loan::KINDS

  # Status in the order of Loan::STATUSES (active, overdue, paid off); kind
  # and what is owed today are computed: sorted in Ruby.
  sorts number: "loans.id",
        person: { sql: text("people.first_names", "people.last_names"), joins: :person },
        disbursed_on: "loans.disbursed_on", due_on: "loans.due_on", rate: "loans.monthly_interest_rate",
        kind: { ruby: ->(loan) { Loan.human_attribute_name("kind/#{loan.kind}") } },
        principal: "loans.principal",
        owed: { ruby: ->(loan) { loan.balance.total_owed } },
        status: -> { "CASE WHEN loans.paid_off_on IS NOT NULL THEN 2 WHEN loans.due_on < #{ActiveRecord::Base.connection.quote(Time.zone.today)} THEN 1 ELSE 0 END" }

  def apply(scope)
    scope = scope.where(disbursed_on: from..) if from
    scope = scope.where(disbursed_on: ..to) if to
    scope = scope.where(person_id: Person.search(q).select(:id)) if q
    scope = scope.with_status(status) if status
    scope = scope.of_kind(kind) if kind
    scope.includes(:person, :payments, :supply_items).newest_first
  end
end
