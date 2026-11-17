# What goes to be processed is taken from invoices (Fernando, 2026-11-16),
# through lots: a lot goes to a shipment or to a process, never both.
class AddCoffeeConversionToCoffeeBatches < ActiveRecord::Migration[8.1]
  def change
    add_reference :coffee_batches, :coffee_conversion, foreign_key: true
    add_check_constraint :coffee_batches, "shipment_id IS NULL OR coffee_conversion_id IS NULL", name: "coffee_batches_one_destination"
  end
end
