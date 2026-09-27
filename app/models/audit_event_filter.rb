class AuditEventFilter < ListFilter
  field :from, :date
  field :to, :date
  field :user_id, :id
  field :event_action, :choice, in: AuditEvent::ACTIONS
  field :auditable_type, :choice, in: AuditEvent::AUDITED_TYPES
  field :auditable_id, :id
  field :q, :text

  def apply(scope)
    scope = scope.where(created_at: from.in_time_zone.beginning_of_day..) if from
    scope = scope.where(created_at: ..to.in_time_zone.end_of_day) if to
    scope = scope.where(user_id:) if user_id
    scope = scope.where(action: event_action) if event_action
    scope = scope.where(auditable_type:) if auditable_type
    scope = scope.where(auditable_id:) if auditable_id
    scope = scope.where("auditable_label ILIKE :q OR user_email ILIKE :q", q: like(q)) if q
    scope.newest_first.includes(:user)
  end
end
