# Undoes a Consolidación (AccountConsolidation) from its audit trail, for
# when one was done by mistake (Fernando, 2026-10-31). Run from a console:
# bin/rails consolidation:list / consolidation:revert (lib/tasks).
#
# A consolidation leaves, per record, an "update" audit event that changes
# only the account (from none) and/or the payroll expense category; all the
# events of one consolidation share the request_id. Reverting puts back the
# value from before, only where the record still has the one the
# consolidation gave (a later change by hand is left alone). Each revert is
# audited like any change; all of it or nothing.
class ConsolidationRevert
  COLUMNS = %w[money_account_id expense_category_id].freeze

  Change = Data.define(:event, :record, :restore)
  Group = Data.define(:request_id, :at, :user, :events)

  # Consolidations, newest first: one group per request.
  def self.groups
    events = AuditEvent.where(action: "update", auditable_type: AccountConsolidation::MODELS.values)
      .where("changeset ?| array[:columns]", columns: COLUMNS)
      .order(:created_at, :id).to_a
      .select { |event| consolidation?(event) }
    events.group_by { |event| event.request_id || "event-#{event.id}" }.map do |request_id, group|
      Group.new(request_id:, at: group.first.created_at, user: group.first.user_email, events: group)
    end.sort_by(&:at).reverse
  end

  def self.consolidation?(event)
    keys = event.changeset.keys
    return false if keys.empty? || (keys - COLUMNS).any?

    account = event.changeset["money_account_id"]
    account.nil? || (account.first.nil? && account.last.present?)
  end

  # request_ids: the consolidations to undo, or :all.
  def initialize(request_ids)
    groups = self.class.groups
    @groups = request_ids == :all ? groups : groups.select { |group| Array(request_ids).include?(group.request_id) }
  end

  attr_reader :groups

  # What would change: the records whose values are still the consolidation's.
  def changes
    @changes ||= groups.flat_map(&:events).filter_map do |event|
      record = event.auditable_type.constantize.find_by(id: event.auditable_id)
      next unless record

      restore = event.changeset.select { |column, (_before, after)| record[column] == after }
                     .transform_values(&:first)
      Change.new(event:, record:, restore:) if restore.any?
    end
  end

  def apply!
    ActiveRecord::Base.transaction do
      changes.count do |change|
        record = change.record.lock!
        # Still the consolidation's value once locked.
        restore = change.restore.select { |column, _| record[column] == change.event.changeset[column].last }
        record.assign_attributes(restore)
        record.changed? && record.save!(validate: false)
      end
    end
  end
end
