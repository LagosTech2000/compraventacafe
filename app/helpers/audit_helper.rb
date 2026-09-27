module AuditHelper
  def audit_user(event)
    return t("administration.audit_events.system") unless event.user_email

    event.user ? "#{event.user.name} (#{event.user_email})" : event.user_email
  end

  def audit_attribute_name(event, attribute)
    model = event.auditable_type&.safe_constantize
    model ? model.human_attribute_name(attribute) : attribute.humanize
  end

  # Readable value: booleans as Sí/No, closed lists translated, secrets hidden.
  def audit_value(event, attribute, value)
    return t("administration.audit_events.filtered") if value == AuditEvent::FILTERED
    return "—" if value.nil? || value == ""
    return t("administration.audit_events.#{value}") if value == true || value == false

    model = event.auditable_type&.safe_constantize
    key = "activerecord.attributes.#{model&.model_name&.i18n_key}.#{attribute}/#{value}"
    model && I18n.exists?(key) ? t(key) : value.to_s
  end

  def audit_action_badge(event)
    classes = {
      "create" => "bg-success-soft text-success", "destroy" => "bg-danger-soft text-danger",
      "sign_in_failed" => "bg-danger-soft text-danger"
    }.fetch(event.action, "bg-primary-soft text-primary")
    tag.span(event.human_action, class: "whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-medium #{classes}")
  end
end
