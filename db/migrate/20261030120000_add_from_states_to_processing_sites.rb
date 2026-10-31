# Each kind of process has its own list of places (client, 2026-10-30: «cada
# tipo de proceso debe tener su propia lista de lugares»): a place says which
# processes are done there, by the state that goes in (cherry → wet parchment,
# wet → dry parchment). One place can do both (the patio).
#
# The places already registered keep the processes they were used for; one
# never used takes both, so no list loses it (it is edited after).
class AddFromStatesToProcessingSites < ActiveRecord::Migration[8.1]
  def up
    add_column :processing_sites, :from_states, :string, array: true, null: false, default: []

    execute <<~SQL
      UPDATE processing_sites s
         SET from_states = COALESCE(
               (SELECT array_agg(DISTINCT c.from_state ORDER BY c.from_state)
                  FROM coffee_conversions c
                 WHERE c.processing_site_id = s.id),
               ARRAY['cherry', 'wet_parchment']::varchar[])
    SQL
  end

  def down
    remove_column :processing_sites, :from_states
  end
end
