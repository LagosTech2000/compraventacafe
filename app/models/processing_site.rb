# Where coffee is processed (client, 2026-10-26): the ecological machines
# of others where cherry is pulped, the business's patio, a dryer that
# charges… A catalog chosen in each process. Deactivated, never deleted.
#
# Each kind of process has its own list (client, 2026-10-30): a place says
# which processes are done there, by the state that goes in
# (CoffeeConversion::NEXT_STATE keys). One place can do both.
class ProcessingSite < ApplicationRecord
  include Auditable
  include LiveUpdates
  live_updates :sales

  has_many :coffee_conversions, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.squish.presence }
  normalizes :observations, with: FieldFormats::STRIP
  normalizes :from_states, with: ->(states) { CoffeeConversion::NEXT_STATE.keys & Array(states) }

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { case_sensitive: false }
  validates :observations, length: { maximum: 500 }
  validates :from_states, presence: true

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  scope :for_state, ->(from_state) { where("? = ANY (processing_sites.from_states)", from_state) }

  def self.options_for(selected_id) = active.or(where(id: selected_id)).alphabetical

  def processes?(from_state) = from_states.include?(from_state)

  # «Uva → Pergamino húmedo, Pergamino húmedo → Pergamino seco»
  def human_processes = from_states.map { CoffeeConversion.human_process(it) }.join(", ")

  def audit_label = name
end
