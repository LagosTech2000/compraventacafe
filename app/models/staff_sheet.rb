# The payroll sheet of the Planilla interna (Fernando, 2026-10-25): the
# client's Excel, alive, in three views.
#
#   fortnight  1–15 or 16–end of a month: every employee with their days
#              (marked here), monthly salary, days, earned (salary ÷ 30 ×
#              days), advances of the fortnight, total, and whether its
#              period is paid, to pay or running; the ones to pay can be
#              paid together.
#   month      the whole month: each fortnight's days and the month's
#              earned, advances, total, what was paid and what is left.
#   history    the months of a season: what each one was paid month by
#              month (what its periods earned: the net plus the advances
#              taken off), and in the current month what is paid and what
#              is still to pay, estimated as if the days left are worked.
#
# Days follow StaffMember#days_in, fortnight by fortnight (15 at most, 15
# for one worked whole), like the Excel.
class StaffSheet
  VIEWS = %w[fortnight month history].freeze
  FORTNIGHT_DAYS = 15

  Row = Data.define(:member, :days, :earned, :advances, :paid, :period, :status, :payable, :fortnights) do
    def total = earned - advances
    def pending = [ total - paid, 0.to_d ].max
  end
  HistoryRow = Data.define(:member, :by_month, :paid_now, :pending_now) do
    def season_total = by_month.values.sum(0.to_d) + paid_now
    def month_total = paid_now + pending_now
  end

  attr_reader :view, :month, :half, :today, :season

  def initialize(view: nil, month: nil, half: nil, season_year: nil, today: Time.zone.today)
    @today = today
    @view = VIEWS.include?(view.to_s) ? view.to_s : "fortnight"
    @month = parse_month(month) || today.beginning_of_month
    @half = [ 1, 2 ].include?(half.to_i) ? half.to_i : (@month == today.beginning_of_month && today.day > FORTNIGHT_DAYS ? 2 : 1)
    @season = season_year.to_s.match?(/\A\d{4}\z/) ? Season.new(season_year.to_i) : Season.for(today)
  end

  def fortnight = half == 1 ? month..month.change(day: FORTNIGHT_DAYS) : month.change(day: FORTNIGHT_DAYS + 1)..month.end_of_month
  def fortnights = [ month..month.change(day: FORTNIGHT_DAYS), month.change(day: FORTNIGHT_DAYS + 1)..month.end_of_month ]
  def dates = view == "fortnight" ? fortnight : month..month.end_of_month

  # The neighbours, for the arrows.
  def previous = half == 2 && view == "fortnight" ? [ month, 1 ] : [ month.prev_month, view == "fortnight" ? 2 : 1 ]
  def following = half == 1 && view == "fortnight" ? [ month, 2 ] : [ month.next_month, 1 ]

  # The employees working some day of the sheet (also one who left).
  def members
    @members ||= begin
      range = view == "history" ? season.starts_on..season.ends_on : dates
      StaffMember.where(starts_on: ..range.last).where("staff_members.ends_on IS NULL OR staff_members.ends_on >= ?", range.first)
                 .includes({ person: :photo_info }, :role, :payments, :advances, :goals, :attendances).newest_first.to_a
    end
  end

  def rows = @rows ||= members.map { |member| row_for(member) }

  def totals
    %i[days earned advances total paid pending].index_with { |key| rows.sum(0.to_d) { it.public_send(key) } }
  end

  def payable_rows = rows.select(&:payable)

  # --- history ---------------------------------------------------------------

  # The season's months up to the current one (the current one apart).
  def past_months
    last = [ season.ends_on, today ].min.beginning_of_month
    months = []
    current = season.starts_on.beginning_of_month
    while current <= last
      months << current unless current == today.beginning_of_month
      current = current.next_month
    end
    months
  end

  def current_month_in_season? = season.dates.cover?(today)

  def history_rows = @history_rows ||= members.map { |member| history_row_for(member) }

  def history_totals
    { months: past_months.index_with { |m| history_rows.sum(0.to_d) { it.by_month.fetch(m, 0) } },
      paid_now: history_rows.sum(0.to_d, &:paid_now), pending_now: history_rows.sum(0.to_d, &:pending_now),
      season: history_rows.sum(0.to_d, &:season_total) }
  end

  private
    def parse_month(value)
      Date.strptime(value.to_s, "%Y-%m") if value.to_s.match?(/\A\d{4}-\d{2}\z/)
    rescue Date::Error
      nil
    end

    def row_for(member)
      parts = view == "fortnight" ? [ dates ] : fortnights
      days_by_fortnight = parts.map { |part| member.days_in(part, nominal: FORTNIGHT_DAYS) }
      days = days_by_fortnight.sum
      period = view == "fortnight" ? member.period_on(dates.first) : nil
      Row.new(member:, days:, earned: member.earned(days), advances: member.advances_in(dates).sum(0.to_d, &:amount),
              paid: paid_in(member, dates), period:, status: status_of(member, period), payable: payable?(member, period),
              fortnights: days_by_fortnight)
    end

    # What its payments of periods inside these dates earned (net + advances).
    def paid_in(member, range)
      member.payments.select { range.cover?(it.period_ends_on) }.sum(0.to_d) { it.net_total + it.advances_total }
    end

    def status_of(member, period)
      return "no_salary" unless member.role.priced?
      return unless period

      if member.paid_period?(period) then "paid"
      elsif period.due?(today) then "due"
      else "running"
      end
    end

    # Paid together: the next period to pay, already due, inside this
    # fortnight, with no goal waiting to be marked (those go one by one).
    def payable?(member, period)
      period.present? && member.period_to_pay(today) == period && period.due?(today) &&
        period.starts_on >= dates.first && period.ends_on <= dates.last &&
        member.goals.none? { !it.paid? && period.include?(it.period_starts_on) }
    end

    def history_row_for(member)
      by_month = past_months.index_with { |m| paid_in(member, m..m.end_of_month) }
      return HistoryRow.new(member:, by_month:, paid_now: 0.to_d, pending_now: 0.to_d) unless current_month_in_season?

      current = today.beginning_of_month
      paid_now = paid_in(member, current..current.end_of_month) +
                 member.pending_advances.select { (current..current.end_of_month).cover?(it.given_on) }.sum(0.to_d, &:amount)
      HistoryRow.new(member:, by_month:, paid_now:, pending_now: pending_this_month(member, current))
    end

    # The fortnights of this month not paid yet, as if the days left are
    # worked, minus the advances already given in them.
    def pending_this_month(member, current)
      [ current..current.change(day: FORTNIGHT_DAYS), current.change(day: FORTNIGHT_DAYS + 1)..current.end_of_month ].sum(0.to_d) do |part|
        next 0.to_d if member.payments.any? { part.cover?(it.period_ends_on) }

        days = projected_days(member, part)
        advances = member.pending_advances.select { part.cover?(it.given_on) }.sum(0.to_d, &:amount)
        [ member.earned(days) - advances, 0.to_d ].max
      end
    end

    def projected_days(member, part)
      past = part.select { it <= today }
      ahead = part.select { it > today && member.employed_on?(it) }
      whole = part.all? { member.employed_on?(it) } && past.all? { member.day_on(it) == 1 }
      whole ? FORTNIGHT_DAYS.to_d : [ past.sum(0.to_d) { member.day_on(it) } + ahead.size, FORTNIGHT_DAYS.to_d ].min
    end
end
