# A report needs the reports module's read permission and the read
# permission of every module whose data it shows (Report.permission_keys).
class ReportPolicy < ApplicationPolicy
  self.module_key = "reports"
  self.submodule_key = "reports"

  def show?
    can?(:read) && report_class.readable_by?(user)
  end

  def charts? = show?

  private
    def report_class = record.is_a?(Class) ? record : record.class
end
