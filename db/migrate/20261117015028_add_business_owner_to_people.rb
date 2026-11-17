# The owners of the business (Fernando, 2026-11-16): a person marked as one
# buys the coffee of the business's own farms too. The owner registered
# until now is the producer of kind «Finca propia», and that producer's farm
# is the business's (Fernando, the same day): it passes to the business's
# farms, with its purchases, unless the business already has one of that
# name. SQL only, no app models.
class AddBusinessOwnerToPeople < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :business_owner, :boolean, null: false, default: false

    execute <<~SQL
      UPDATE people SET business_owner = TRUE
      WHERE id IN (SELECT person_id FROM producers WHERE kind = 'own_farm')
    SQL
    execute <<~SQL
      UPDATE farms SET producer_id = NULL
      WHERE producer_id IN (SELECT id FROM producers WHERE kind = 'own_farm')
        AND NOT EXISTS (SELECT 1 FROM farms AS business WHERE business.producer_id IS NULL AND LOWER(business.name) = LOWER(farms.name))
    SQL
  end

  def down
    remove_column :people, :business_owner
  end
end
