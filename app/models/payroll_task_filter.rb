class PayrollTaskFilter < ListFilter
  STATUSES = %w[pending completed].freeze

  field :q, :text
  field :status, :choice, in: STATUSES

  # Who did it and each one's part come from the participants: sorted in Ruby.
  sorts name: text("payroll_tasks.name"), completed_on: "payroll_tasks.completed_on", amount: "payroll_tasks.amount",
        members: { ruby: ->(task) { task.shares.keys.map(&:full_name).sort.join(", ") } },
        share: { ruby: ->(task) { task.shares.values.min } }

  def apply(scope)
    scope = scope.where("name ILIKE ?", like(q)) if q
    scope = scope.public_send(status) if status
    scope.includes(participants: { member: :person }).newest_first
  end
end
