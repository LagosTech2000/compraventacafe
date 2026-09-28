module AuditHelper
  def audit_actor(event)
    event.user&.name || event.user_email || t("administration.audit_events.system_actor")
  end

  # "la compra #57 (Ana Demo Uno)"; for a failed sign-in, the email tried.
  def audit_record_phrase(event)
    return event.auditable_label.to_s if event.auditable_type.nil?

    entity = t("administration.audit_events.entities.#{event.auditable_type.underscore}")
    [ entity, ("##{event.auditable_id}" if event.auditable_id), ("(#{event.auditable_label})" if event.auditable_label.present?) ].compact.join(" ")
  end

  def audit_changed_fields(event)
    event.changeset.keys.map { |attribute| audit_attribute_name(event, attribute) }.to_sentence
  end

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

  # One sentence per event, e.g. "Susana Marcia modificó la compra #57
  # (Ana Demo Uno): Precio por libra (L) y Total, el 27/09/2026 a las 15:31:02."
  def audit_sentence(event)
    t("administration.audit_events.sentence.#{event.action}",
      actor: audit_actor(event),
      record: audit_record_phrase(event),
      fields: audit_changed_fields(event),
      date: l(event.created_at.to_date),
      time: l(event.created_at, format: :time_only))
  end

  def audit_action_badge(event)
    classes = {
      "create" => "bg-success-soft text-success", "destroy" => "bg-danger-soft text-danger",
      "sign_in_failed" => "bg-danger-soft text-danger"
    }.fetch(event.action, "bg-primary-soft text-primary")
    tag.span(event.human_action, class: "whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-medium #{classes}")
  end
end
