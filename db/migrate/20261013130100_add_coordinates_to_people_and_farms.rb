# Where a person or a farm is, picked on a map (Fernando, 2026-10-13).
# Optional, as the rest of the address.
class AddCoordinatesToPeopleAndFarms < ActiveRecord::Migration[8.1]
  def change
    %i[people farms].each do |table|
      add_column table, :latitude, :decimal, precision: 9, scale: 6
      add_column table, :longitude, :decimal, precision: 9, scale: 6
    end
  end
end
