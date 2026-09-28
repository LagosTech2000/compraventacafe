class CreateProducers < ActiveRecord::Migration[8.1]
  def change
    create_table :producers do |t|
      t.references :person, null: false, foreign_key: true, index: { unique: true }
      t.references :zone, foreign_key: true
      t.string :kind, null: false
      t.string :farm_name

      t.timestamps
    end
  end
end
