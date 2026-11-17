# Employees deactivated without an end date end on their last day worked or
# paid (Fernando, 2026-11-16), so the payroll sheet shows them only while
# they were employed. SQL only, no app models.
class EndInactiveStaffMembers < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE staff_members SET ends_on = GREATEST(
        staff_members.starts_on,
        (SELECT MAX(period_ends_on) FROM staff_payments WHERE staff_payments.staff_member_id = staff_members.id),
        (SELECT MAX(worked_on) FROM staff_attendances WHERE staff_attendances.staff_member_id = staff_members.id))
      WHERE active = false AND ends_on IS NULL
    SQL
  end

  def down
    # The dates set here cannot be told from the ones written by hand.
  end
end
