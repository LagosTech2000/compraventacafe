class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    # Append-only log. Labels and the user's email are snapshots, so an event
    # stays readable after the record it describes changes or disappears.
    create_table :audit_events do |t|
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :user_email
      t.string :action, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.string :auditable_label
      t.jsonb :changeset, null: false, default: {}
      t.string :ip_address
      t.string :request_id
      t.datetime :created_at, null: false
    end
    add_index :audit_events, :created_at
    add_index :audit_events, :action
    add_index :audit_events, [ :auditable_type, :auditable_id ]
  end
end
