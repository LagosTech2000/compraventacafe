# Filters of a report that a user saved with a name, to run it again later
# ("Mis filtros"). The params are the report's own (ReportFilter#to_params):
# a period is stored by its key, so "Este mes" stays the current month.
class SavedReport < ApplicationRecord
  include Auditable

  MAX_PER_USER = 100

  belongs_to :user

  normalizes :name, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 60 }, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :report_key, inclusion: { in: ->(_) { Report.catalog.map(&:key) } }
  validate :within_limit, on: :create

  before_validation :clean_params

  scope :ordered, -> { order(Arel.sql("lower(name)")) }

  def audit_label = "#{name} · #{report_class&.title}"

  def report_class = Report.find(report_key)

  private
    # Only the filters the report knows, valid and without the page.
    def clean_params
      self.params = report_class ? report_class.new(params.to_h).filter.to_params.except("page") : {}
    end

    def within_limit
      errors.add(:base, :too_many, count: MAX_PER_USER) if user && user.saved_reports.count >= MAX_PER_USER
    end
end
