# Applies the audit screen's filters to a relation of AuditEvents and pages
# through the result. Unknown or malformed values are ignored.
class AuditEventFilter
  PER_PAGE = 50

  attr_reader :from, :to, :user_id, :action, :auditable_type, :query, :page

  def initialize(params)
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])
    @user_id = params[:user_id].presence
    @action = params[:event_action].presence_in(AuditEvent::ACTIONS)
    @auditable_type = params[:auditable_type].presence_in(AuditEvent::AUDITED_TYPES)
    @query = params[:q].to_s.strip.first(100)
    @page = [ params[:page].to_i, 1 ].max
  end

  # Returns [events of this page, whether there is a next page].
  def apply(scope)
    events = filtered(scope).newest_first.includes(:user).offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    [ events.first(PER_PAGE), events.size > PER_PAGE ]
  end

  def active?
    [ from, to, user_id, action, auditable_type, query.presence ].any?
  end

  def to_params
    { from:, to:, user_id:, event_action: action, auditable_type:, q: query.presence }.compact
  end

  private
    def filtered(scope)
      scope = scope.where(created_at: from.in_time_zone.beginning_of_day..) if from
      scope = scope.where(created_at: ..to.in_time_zone.end_of_day) if to
      scope = scope.where(user_id:) if user_id
      scope = scope.where(action:) if action
      scope = scope.where(auditable_type:) if auditable_type
      scope = scope.where("auditable_label ILIKE :q OR user_email ILIKE :q", q: "%#{AuditEvent.sanitize_sql_like(query)}%") if query.present?
      scope
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end
end
