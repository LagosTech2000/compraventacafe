# Producers' farms become farms (the same table as the business's farms),
# each with its producer; purchases get a farm of their producer. Names are
# unique among the business's farms and, apart, among each producer's own.
# The text column producers.farm_name is filled into farms and then dropped
# (ProducerFarmBackfill).
class AssignFarmsToProducers < ActiveRecord::Migration[8.1]
  def up
    add_reference :farms, :producer, foreign_key: true
    add_reference :purchases, :farm, foreign_key: true

    remove_index :farms, name: "index_farms_on_lower_name"
    add_index :farms, "lower((name)::text)", unique: true, where: "producer_id IS NULL", name: "index_farms_on_lower_name"
    add_index :farms, "producer_id, lower((name)::text)", unique: true, where: "producer_id IS NOT NULL",
                                                          name: "index_farms_on_producer_and_lower_name"

    Farm.reset_column_information
    Purchase.reset_column_information
    say_with_time("Backfilling the producers' farms") { ProducerFarmBackfill.new.call.to_h.to_s }

    remove_column :producers, :farm_name
  end

  def down
    add_column :producers, :farm_name, :string
    execute <<~SQL
      UPDATE producers SET farm_name = (SELECT name FROM farms WHERE farms.producer_id = producers.id ORDER BY farms.id LIMIT 1)
    SQL
    remove_reference :purchases, :farm
    remove_index :farms, name: "index_farms_on_producer_and_lower_name"
    remove_index :farms, name: "index_farms_on_lower_name"
    execute "DELETE FROM farms WHERE producer_id IS NOT NULL"
    remove_reference :farms, :producer
    add_index :farms, "lower((name)::text)", unique: true, name: "index_farms_on_lower_name"
  end
end
