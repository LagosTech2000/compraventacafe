# "Cobrar con café" (Fernando, 2026-11-03): the people who owe loans and
# have coffee purchases whose money can still go to them (not voided, not
# paid out: Purchase#available_for_loans), each with what they owe today and
# those purchases. Paying is the usual "pago con café" of each purchase
# (PurchaseLoanSettlement): how much goes to the loans is chosen there.
class CoffeeCollectionFilter < ListFilter
  PERIODS = %w[today week month].freeze

  # items: [[purchase, money available for loans], ...], the newest first.
  Row = Data.define(:person, :account, :items) do
    def id = person.id
    def available = items.sum(0.to_d) { it.last }
    def last_purchased_at = items.map { it.first.purchased_at }.max
    def next_due_on = account.open_loans.map(&:due_on).min
  end

  field :q, :text
  field :period, :choice, in: PERIODS

  sorts person: { ruby: ->(row) { [ row.person.first_names, row.person.last_names ] } },
        last_purchase: { ruby: ->(row) { row.last_purchased_at } },
        available: { ruby: ->(row) { row.available } },
        owed: { ruby: ->(row) { row.account.total_owed } },
        due_on: { ruby: ->(row) { row.next_due_on } }

  def self.rows
    purchases = Purchase.active.left_joins(:invoice).where("invoices.id IS NULL OR invoices.payment_status <> 'paid'")
                        .joins(:producer).where(producers: { person_id: Loan.unpaid.select(:person_id) })
                        .includes(:loan_payments, invoice: [ :payments, { purchases: :loan_payments } ],
                                  producer: { person: [ :zone, :photo_info, { loans: %i[payments supply_items] } ] })
                        .order(purchased_at: :desc, id: :desc).to_a
    items = purchases.filter_map do |purchase|
      available = purchase.available_for_loans_loaded
      [ purchase, available ] if available.positive?
    end
    items.group_by { it.first.producer.person_id }.map do |_, group|
      person = group.first.first.producer.person
      Row.new(person:, account: CreditAccount.new(person), items: group)
    end
  end

  # rows: [Row, ...]; the latest purchase first.
  def apply(rows)
    if q
      matching = Person.search(q).where(id: rows.map(&:id)).pluck(:id).to_set
      rows = rows.select { matching.include?(it.id) }
    end
    if (since = since_time)
      rows = rows.filter_map do |row|
        items = row.items.select { it.first.purchased_at >= since }
        row.with(items:) if items.any?
      end
    end
    rows.sort_by { -it.last_purchased_at.to_f }
  end

  private
    def since_time
      today = Time.zone.today
      case period
      when "today" then today.beginning_of_day
      when "week" then (today - 6).beginning_of_day
      when "month" then (today - 29).beginning_of_day
      end
    end
end
