# Coffee varieties of a farm or a plot (Fernando, 2026-11-15): one or more
# of the catalog (CoffeeVariety), kept as ids so a change is audited as one
# field.
module HasVarieties
  extend ActiveSupport::Concern

  included do
    normalizes :variety_ids, with: ->(ids) { Array(ids).reject(&:blank?).map(&:to_i).uniq.sort }
    validate :varieties_exist, if: :will_save_change_to_variety_ids?
  end

  def varieties = CoffeeVariety.where(id: variety_ids).alphabetical
  def variety_names = varieties.pluck(:name)

  private
    def varieties_exist
      errors.add(:variety_ids, :invalid) if CoffeeVariety.where(id: variety_ids).count != variety_ids.size
    end
end
