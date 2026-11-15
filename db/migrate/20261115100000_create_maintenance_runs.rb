# Each run of a data maintenance task (Administración → Mantenimiento de
# datos, or its rake from the Render shell; Fernando, 2026-11-15): what was
# run, with what, what it found and, when it changed data, what it changed,
# so it can be undone.
class CreateMaintenanceRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :maintenance_runs do |t|
      t.string :task_key, null: false
      t.string :mode, null: false
      t.jsonb :params, null: false, default: {}
      t.string :status, null: false
      t.jsonb :sections, null: false, default: []
      t.jsonb :changes_made, null: false, default: {}
      t.text :error
      t.integer :duration_ms
      t.string :request_id
      t.references :user, foreign_key: true
      t.references :reverted_run, foreign_key: { to_table: :maintenance_runs }
      t.datetime :reverted_at
      t.timestamps
    end
    add_index :maintenance_runs, [ :task_key, :created_at ]
  end
end
