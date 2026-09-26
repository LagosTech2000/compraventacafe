class CreateDepartmentsAndMunicipalities < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.string :code, null: false, index: { unique: true }
      t.string :name, null: false

      t.timestamps
    end

    create_table :municipalities do |t|
      t.references :department, null: false, foreign_key: true
      t.string :code, null: false, index: { unique: true }
      t.string :name, null: false

      t.timestamps
    end

    reversible do |direction|
      direction.up { HondurasDivisions.load! }
    end
  end
end
