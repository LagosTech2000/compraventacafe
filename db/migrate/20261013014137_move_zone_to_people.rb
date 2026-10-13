# The zone a person is from now lives on the person, shown in every person
# form (Fernando, 2026-10-12). A producer's zone is its person's: copied
# over, then the producer's own column goes.
class MoveZoneToPeople < ActiveRecord::Migration[8.1]
  def up
    add_reference :people, :zone, foreign_key: true
    execute <<~SQL
      UPDATE people SET zone_id = producers.zone_id
      FROM producers WHERE producers.person_id = people.id AND producers.zone_id IS NOT NULL
    SQL
    remove_reference :producers, :zone, foreign_key: true, index: true
  end

  def down
    add_reference :producers, :zone, foreign_key: true
    execute <<~SQL
      UPDATE producers SET zone_id = people.zone_id
      FROM people WHERE producers.person_id = people.id AND people.zone_id IS NOT NULL
    SQL
    remove_reference :people, :zone, foreign_key: true, index: true
  end
end
