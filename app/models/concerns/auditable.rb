# Records create, update and destroy in AuditEvent, in the same transaction
# as the change: if the change rolls back, so does its audit entry.
#
# Models may override #audit_label to name the record in the log.
module Auditable
  extend ActiveSupport::Concern

  IGNORED_ATTRIBUTES = %w[id created_at updated_at].freeze
  SENSITIVE_ATTRIBUTES = %w[password_digest].freeze

  included do
    after_create { record_audit("create", saved_changes) }
    after_update { record_audit("update", saved_changes) }
    after_destroy { record_audit("destroy", attributes.transform_values { |value| [ value, nil ] }) }
  end

  def audit_label
    "#{self.class.model_name.human} #{id}"
  end

  private
    def record_audit(action, changes)
      changeset = audit_changeset(changes)
      return if action == "update" && changeset.empty?

      AuditEvent.record!(action:, auditable: self, changeset:)
    end

    def audit_changeset(changes)
      changes.except(*IGNORED_ATTRIBUTES).to_h do |attribute, (before, after)|
        if SENSITIVE_ATTRIBUTES.include?(attribute)
          [ attribute, [ before && AuditEvent::FILTERED, after && AuditEvent::FILTERED ] ]
        else
          [ attribute, [ before, after ] ]
        end
      end
    end
end
