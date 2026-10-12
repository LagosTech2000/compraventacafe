class AddIhcafeCodeToProducers < ActiveRecord::Migration[8.1]
  def change
    add_column :producers, :ihcafe_code, :string
    add_index :producers, :ihcafe_code, unique: true, where: "ihcafe_code IS NOT NULL"
  end
end
