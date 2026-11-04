# What is owed today on the unpaid loans, by how near or how late their due
# date is ("Cartera", Fernando, 2026-11-03), in total and by the zone of the
# person. Only sums of what each loan owes today (LoanBalance); nothing is
# estimated.
#
# The tramos (a presentation choice, pending confirmation): due in more than
# SOON_DAYS days, due within SOON_DAYS days, and late 1–30, 31–60, 61–90 and
# more than 90 days.
class LoanAging
  BUCKETS = %w[current due_soon late_30 late_60 late_90 late_more].freeze
  LATE = %w[late_30 late_60 late_90 late_more].freeze
  SOON_DAYS = 30

  Row = Data.define(:key, :loans_count, :people_count, :principal, :interest) do
    def total = principal + interest
    def late? = LATE.include?(key)
  end
  ZoneRow = Data.define(:zone, :by_bucket) do
    def total = by_bucket.values.sum(0.to_d)
    def late = by_bucket.slice(*LATE).values.sum(0.to_d)
  end

  attr_reader :today

  def initialize(today: Time.zone.today)
    @today = today
  end

  def loans
    @loans ||= Loan.unpaid.includes(:payments, :supply_items, person: :zone).to_a
  end

  def balance(loan) = balances.fetch(loan.id)

  def bucket_for(loan)
    late = (today - loan.due_on).to_i
    if late <= 0 then -late > SOON_DAYS ? "current" : "due_soon"
    elsif late <= 30 then "late_30"
    elsif late <= 60 then "late_60"
    elsif late <= 90 then "late_90"
    else "late_more"
    end
  end

  def rows
    @rows ||= BUCKETS.map do |key|
      group = by_bucket.fetch(key, [])
      Row.new(key:, loans_count: group.size, people_count: group.map(&:person_id).uniq.size,
              principal: group.sum(0.to_d) { balance(it).principal_owed }, interest: group.sum(0.to_d) { balance(it).interest_owed })
    end
  end

  def total = rows.sum(0.to_d, &:total)
  def late_total = rows.select(&:late?).sum(0.to_d, &:total)
  def loans_count = loans.size
  def people_count = loans.map(&:person_id).uniq.size

  # One row per zone (nil = people without a zone), the most owed first.
  def zones
    @zones ||= loans.group_by { it.person.zone }.map do |zone, zone_loans|
      sums = zone_loans.group_by { bucket_for(it) }.transform_values { |group| group.sum(0.to_d) { balance(it).total_owed } }
      ZoneRow.new(zone:, by_bucket: BUCKETS.index_with { sums.fetch(it, 0.to_d) })
    end.sort_by { -it.total }
  end

  # The due dates of a tramo, for the loans list (LoanFilter due_from / due_to).
  def due_range(key)
    case key
    when "current" then [ today + SOON_DAYS + 1, nil ]
    when "due_soon" then [ today, today + SOON_DAYS ]
    when "late_30" then [ today - 30, today - 1 ]
    when "late_60" then [ today - 60, today - 31 ]
    when "late_90" then [ today - 90, today - 61 ]
    when "late_more" then [ nil, today - 91 ]
    end
  end

  private
    def by_bucket = @by_bucket ||= loans.group_by { bucket_for(it) }
    def balances = @balances ||= loans.to_h { [ it.id, it.balance(as_of: today) ] }
end
