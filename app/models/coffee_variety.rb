# A coffee variety (Fernando, 2026-11-15: «hay que registrar la variedad del
# café, por finca y parcela»): Lempira, IHCAFE 90, Parainema… a catalog the
# users grow, rename and deactivate (Fincas → Variedades). A deactivated one
# is not chosen again; farms and plots that have it keep it.
class CoffeeVariety < ApplicationRecord
  include Auditable

  normalizes :name, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 60 }, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  def audit_label = name

  # The ones to choose in a form: the active ones and those already chosen.
  def self.options(chosen_ids = [])
    where(active: true).or(where(id: chosen_ids)).alphabetical
  end
end
