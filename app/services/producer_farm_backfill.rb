# Turns the producers' farm written as text (the old producers.farm_name)
# into farms of their own (Farm with producer_id), and gives each producer's
# purchases that farm. A farm is looked for among that producer's farms
# only, by name without regard to case or extra spaces ("finca x" is
# "Finca X"): it is used if it exists, created otherwise. Safe to run again.
#
#   ProducerFarmBackfill.new.call                 # reads producers.farm_name
#   ProducerFarmBackfill.new([[producer_id, "Finca X"], ...]).call
class ProducerFarmBackfill
  Result = Data.define(:farms_created, :producers, :purchases)

  def initialize(rows = nil)
    @rows = rows
  end

  def call
    created = producers = purchases = 0
    rows.each do |producer_id, text|
      name = text.to_s.squish
      next if name.empty?

      farm = Farm.where(producer_id:).find_by("LOWER(name) = ?", name.downcase)
      unless farm
        farm = Farm.create!(name:, producer_id:)
        created += 1
      end
      producers += 1
      purchases += Purchase.where(producer_id:, farm_id: nil).update_all(farm_id: farm.id)
    end
    Result.new(farms_created: created, producers:, purchases:)
  end

  private
    def rows
      @rows || ActiveRecord::Base.connection.select_rows("SELECT id, farm_name FROM producers WHERE farm_name IS NOT NULL ORDER BY id")
    end
end
