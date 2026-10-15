# A farm's land (Fernando, 2026-10-14): optional, written in the unit the
# user picks (manzanas, hectares or square meters); the others are
# calculated from it (FarmArea).
class AddAreaToFarms < ActiveRecord::Migration[8.1]
  def change
    add_column :farms, :area_value, :decimal, precision: 14, scale: 4
    add_column :farms, :area_unit, :string
  end
end
