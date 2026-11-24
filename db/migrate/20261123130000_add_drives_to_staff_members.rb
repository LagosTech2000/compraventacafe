# Who may be a shipment's driver (Fernando, 2026-11-23: «en motoristas que
# solo se puedan elegir David Díaz y Emmanuel Espinal aparte de los que
# están en planilla como conductor»): the members of the roles «Chofer» or
# «Conductor», and the ones marked «Maneja». Those two are marked here.
class AddDrivesToStaffMembers < ActiveRecord::Migration[8.1]
  def up
    add_column :staff_members, :drives, :boolean, default: false, null: false
    execute <<~SQL
      UPDATE staff_members SET drives = TRUE
      FROM people
      WHERE people.id = staff_members.person_id
        AND ((people.first_names ILIKE 'David%' AND people.last_names ILIKE '%Espinal%Diaz%')
          OR (people.first_names ILIKE 'Emanuel%' AND people.last_names ILIKE 'Espinal%'))
    SQL
  end

  def down
    remove_column :staff_members, :drives
  end
end
