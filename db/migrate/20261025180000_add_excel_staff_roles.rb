# The roles of the business's own payroll, from the client's Excel
# (Fernando, 2026-10-24: «que estos roles se agreguen automáticamente»).
# The Excel has no salaries: a role can wait without salary nor frequency,
# filled in «Editar rol» before paying anyone in it. A role with the same
# name (any case) is left as it is. SQL only, no app models.
class AddExcelStaffRoles < ActiveRecord::Migration[8.1]
  ROLES = [ "CEO", "Administración", "Chofer", "Cargador", "Bodeguero", "Trabajadora DMC", "Cargador de bodega" ].freeze

  def up
    change_column_null :staff_roles, :salary, true
    change_column_null :staff_roles, :pay_frequency, true
    ROLES.each do |name|
      execute <<~SQL.squish
        INSERT INTO staff_roles (name, active, created_at, updated_at)
        SELECT #{quote(name)}, TRUE, NOW(), NOW()
        WHERE NOT EXISTS (SELECT 1 FROM staff_roles WHERE LOWER(name) = LOWER(#{quote(name)}))
      SQL
    end
  end

  def down
    execute "DELETE FROM staff_roles WHERE salary IS NULL AND id NOT IN (SELECT staff_role_id FROM staff_members)"
    execute "UPDATE staff_roles SET salary = 0, pay_frequency = 'monthly' WHERE salary IS NULL OR pay_frequency IS NULL"
    change_column_null :staff_roles, :salary, false
    change_column_null :staff_roles, :pay_frequency, false
  end

  private
    def quote(value) = connection.quote(value)
end
