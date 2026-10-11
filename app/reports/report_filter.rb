# Filters of a report. Every report has a period (ReportPeriod: a key, or
# "custom" with its dates), a sort and a grouping; each report adds its own
# fields (Report.filter). Sort and grouping keys are checked by the report.
class ReportFilter < ListFilter
  DIRECTIONS = %w[asc desc].freeze

  field :period, :text
  field :from, :date
  field :to, :date
  field :group, :text
  field :sort, :text
  field :dir, :choice, in: DIRECTIONS

  # Typed dates only count for a custom period; a listed period ignores them.
  def to_params
    params = super
    params.except!("from", "to") unless params["period"] == "custom"
    params
  end
end
