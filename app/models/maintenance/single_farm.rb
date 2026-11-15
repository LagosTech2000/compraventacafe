module Maintenance
  # purchases:assign_single_farm — a purchase without a farm whose producer
  # has exactly one farm gets that farm (to run it, the client accepts the
  # rule «with one farm, the coffee came from it»). Only the farm changes:
  # never the weight, the amount or the invoice. Each change is audited;
  # undone by emptying the farms it gave (if nobody changed them since).
  class SingleFarm < Task
    self.key = "purchases:assign_single_farm"
    self.tier = :fill
    self.area = :general

    def sections
      found = candidates
      without = Purchase.active.where(farm_id: nil).count
      lines = [ t(:found, count: found.size, without:), t(:producers, count: found.map(&:producer_id).uniq.size) ]
      lines += found.first(LINES).map { t(:line, id: it.id, date: day(it.purchased_at.in_time_zone), farm: it.farm_name) }
      [ section(t(:title_section), found.any? ? "warn" : "ok", lines) ]
    end

    def apply!
      changed = candidates.map do |row|
        purchase = Purchase.lock.find(row.id)
        next unless purchase.farm_id.nil?

        purchase.farm_id = row.single_farm_id
        purchase.save!(validate: false)
        [ purchase.id, row.single_farm_id ]
      end
      { "purchases" => changed.compact }
    end

    def sections_after_apply(changes)
      [ section(t(:title_section), "ok", [ t(:done, count: changes["purchases"].size) ]) ]
    end

    def self.revert!(changes)
      changes["purchases"].count do |purchase_id, farm_id|
        purchase = Purchase.lock.find_by(id: purchase_id)
        next false unless purchase && purchase.farm_id == farm_id

        purchase.farm_id = nil
        purchase.save!(validate: false)
      end
    end

    private
      # Active purchases without a farm whose producer has one farm, with it.
      def candidates
        single = Farm.where.not(producer_id: nil).group(:producer_id).having("COUNT(*) = 1").select("producer_id, MIN(id) AS farm_id")
        Purchase.active.where(farm_id: nil)
                .joins("JOIN (#{single.to_sql}) single_farms ON single_farms.producer_id = purchases.producer_id")
                .joins("JOIN farms ON farms.id = single_farms.farm_id")
                .order(:purchased_at, :id)
                .select("purchases.id, purchases.producer_id, purchases.purchased_at, single_farms.farm_id AS single_farm_id, farms.name AS farm_name")
                .to_a
      end
  end
end
