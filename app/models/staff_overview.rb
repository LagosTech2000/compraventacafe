# The figures above the Planilla interna: active employees, the periods
# already due and not paid (with what they would pay today) and the
# advances not yet taken off.
class StaffOverview
  def initialize(today: Time.zone.today)
    @today = today
  end

  def members
    # In the list's order, so its preloads are the same queries (cached).
    @members ||= StaffMember.active.includes({ person: :photo_info }, :role, :payments, :advances, :goals).newest_first.to_a
  end

  def count = members.size

  # [[member, period], ...] due and not paid, the oldest first.
  def due
    @due ||= members.flat_map { |member| member.due_periods(@today).map { [ member, it ] } }.sort_by { |_, period| period.ends_on }
  end

  def due_amount = due.sum(0.to_d) { |member, period| member.estimate(period).net_total }
  def pending_advances = members.sum(0.to_d) { |member| member.pending_advances.sum(0.to_d, &:amount) }
end
