module Maintenance
  # farms:plots_from_lots — the producers' farms named «Lote 1», «Lote 2»…
  # are plots of a farm (Fernando, 2026-11-15: «lote es una parcela de la
  # finca»). Each producer's lots become plots of one farm named by its
  # place: the farm's address (the village), else its municipality, else
  # the producer's zone (Fernando: «si no dice el nombre, el del lugar o la
  # aldea»). Each plot keeps its land, and its varieties are read from the
  # farm's observations («Variedad Parainema», «90»…). The purchases stay
  # with the farm and now name their plot; a second lot's farm is
  # deactivated (its purchases and payrolls pass to the first). Undone
  # field by field.
  class PlotsFromLots < Task
    self.key = "farms:plots_from_lots"
    self.tier = :fill
    self.area = :general

    LOT = /\A\s*lote(\s|\z)/i

    Plan = Data.define(:producer, :farm, :name, :source, :lots)

    def sections
      plans = plan
      lines = plans.map { describe(it) }
      skipped = skipped_lots.map { t(:no_place, producer: it.producer.full_name, lot: it.name) }
      [
        section(t(:summary), plans.any? ? "warn" : "ok", [ t(:found, lots: plans.sum { it.lots.size }, producers: plans.size) ]),
        section(t(:list), plans.any? ? "warn" : "ok", lines.presence || [ t(:none) ]),
        section(t(:skipped), skipped.any? ? "warn" : "ok", skipped.presence || [ t(:none_skipped) ])
      ]
    end

    def apply!
      changes = { "farms" => [], "plots" => [], "purchases" => [], "payrolls" => [] }
      plan.each do |entry|
        farm = entry.farm
        changes["farms"] << snapshot(farm)
        plots = entry.lots.map do |lot|
          plot = farm.plots.create!(name: lot.name, area_value: lot.area_value, area_unit: lot.area_unit, variety_ids: varieties_in(lot.observations))
          changes["plots"] << plot.id
          Purchase.where(farm_id: lot.id).find_each do |purchase|
            changes["purchases"] << [ purchase.id, purchase.farm_id, purchase.farm_plot_id ]
            purchase.farm_id = farm.id
            purchase.farm_plot_id = plot.id
            purchase.save!(validate: false)
          end
          next plot if lot.id == farm.id

          Payroll.where(farm_id: lot.id).find_each do |payroll|
            changes["payrolls"] << [ payroll.id, payroll.farm_id ]
            payroll.farm_id = farm.id
            payroll.save!(validate: false)
          end
          changes["farms"] << snapshot(lot)
          lot.active = false
          lot.save!(validate: false)
          plot
        end
        farm.name = entry.name
        farm.variety_ids = (farm.variety_ids + plots.flat_map(&:variety_ids)).uniq
        units = entry.lots.map(&:area_unit).uniq
        if entry.lots.many? && units.one? && units.first && entry.lots.all?(&:area_value)
          farm.area_value = entry.lots.sum(&:area_value)
          farm.area_unit = units.first
        end
        farm.save!(validate: false)
      end
      changes
    end

    def sections_after_apply(changes)
      [ section(t(:summary), "ok", [ t(:done, plots: changes["plots"].size, purchases: changes["purchases"].size) ]) ]
    end

    def self.revert!(changes)
      count = 0
      changes["purchases"].each do |id, farm_id, plot_id|
        purchase = Purchase.find_by(id:)
        next unless purchase

        purchase.farm_id = farm_id
        purchase.farm_plot_id = plot_id
        count += 1 if purchase.changed? && purchase.save!(validate: false)
      end
      changes["payrolls"].each do |id, farm_id|
        payroll = Payroll.find_by(id:)
        next unless payroll

        payroll.farm_id = farm_id
        count += 1 if payroll.changed? && payroll.save!(validate: false)
      end
      FarmPlot.where(id: changes["plots"]).where.not(id: Purchase.where.not(farm_plot_id: nil).select(:farm_plot_id)).find_each { count += 1 if it.destroy }
      changes["farms"].each do |values|
        farm = Farm.find_by(id: values["id"])
        next unless farm

        farm.assign_attributes(values.except("id"))
        count += 1 if farm.changed? && farm.save!(validate: false)
      end
      count
    end

    private
      def lots = @lots ||= Farm.where.not(producer_id: nil).includes(:municipality, producer: { person: :zone }).order(:id).select { it.name.match?(LOT) }

      def place_of(farm)
        if (line = farm.address_line.to_s.squish.presence) then [ line, :address ]
        elsif farm.municipality then [ farm.municipality.name, :municipality ]
        elsif (zone = farm.producer.person.zone) then [ zone.name, :zone ]
        end
      end

      def skipped_lots = lots.group_by(&:producer_id).values.filter_map { |group| group.first if place_of(group.first).nil? }

      def plan
        @plan ||= lots.group_by(&:producer_id).values.filter_map do |group|
          base = group.first
          name, source = place_of(base)
          next unless name

          Plan.new(producer: base.producer, farm: base, name:, source:, lots: group)
        end
      end

      def snapshot(farm)
        { "id" => farm.id, "name" => farm.name, "area_value" => farm.area_value&.to_s, "area_unit" => farm.area_unit,
          "variety_ids" => farm.variety_ids, "active" => farm.active }
      end

      # The catalog's varieties named in a text: by name without case or
      # accents, or by its number («90» is IHCAFE 90).
      def varieties_in(text)
        folded = fold(text)
        return [] if folded.empty?

        CoffeeVariety.active.select do |variety|
          name = fold(variety.name)
          number = name[/\d+/]
          folded.include?(name) || name.split.any? { it.length > 3 && folded.match?(/\b#{Regexp.escape(it)}/) } || (number && folded.match?(/\b#{number}\b/))
        end.map(&:id)
      end

      def fold(text) = I18n.transliterate(text.to_s).downcase.squish

      def describe(entry)
        plots = entry.lots.map do |lot|
          area = lot.area_value ? " #{ActiveSupport::NumberHelper.number_to_rounded(lot.area_value, precision: 4, strip_insignificant_zeros: true)} #{I18n.t("farms.area.units.#{lot.area_unit}").downcase}" : ""
          names = CoffeeVariety.where(id: varieties_in(lot.observations)).alphabetical.pluck(:name)
          "#{lot.name}#{area}#{names.any? ? " (#{names.join(", ")})" : ""}"
        end
        t(:line, producer: entry.producer.full_name, name: entry.name, source: t("sources.#{entry.source}"), plots: plots.join("; "),
                 purchases: Purchase.where(farm_id: entry.lots.map(&:id)).count)
      end
  end
end
