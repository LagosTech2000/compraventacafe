class MakeDniAndRtnUnique < ActiveRecord::Migration[8.1]
  def change
    remove_index :people, :dni
    remove_index :people, :rtn
    # Both stay optional (open point), so uniqueness only applies when present.
    add_index :people, :dni, unique: true, where: "dni IS NOT NULL"
    add_index :people, :rtn, unique: true, where: "rtn IS NOT NULL"
  end
end
