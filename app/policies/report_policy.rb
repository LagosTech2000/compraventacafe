# A report needs the reports module's read permission and the read
# permission of every module whose data it shows (Report.module_keys).
class ReportPolicy < ApplicationPolicy
  self.module_key = "reports"

  def show?
    can?(:read) && report_class.module_keys.all? { |key| user.can?(key, :read) }
  end

  def charts? = show?

  private
    def report_class = record.is_a?(Class) ? record : record.class
end
