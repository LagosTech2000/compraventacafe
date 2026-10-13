# Errors are audited too (action "error"): what failed, where and for whom
# goes in details, apart from the before/after of record changes.
class AddDetailsToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :audit_events, :details, :jsonb, default: {}, null: false
  end
end
