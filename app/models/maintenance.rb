# Data maintenance tasks (Fernando, 2026-11-15: «rakes y scripts para
# consolidar la data y tener un número más preciso»): checks that only read
# and say what does not add up, and tasks that fill in what is missing,
# with a preview first and «Deshacer» after. Run from Administración →
# Mantenimiento de datos (only User::DATA_EXPORTER_ID) or from the Render
# shell (lib/tasks/maintenance.rake). Each run is a MaintenanceRun.
module Maintenance
  # The order of the page and of `bin/rails -T`.
  TASKS = %w[
    Maintenance::IntegrityCheck
    Maintenance::Inventory Maintenance::Shipments Maintenance::ShipmentExpenseCandidates Maintenance::BatchesBackfill
    Maintenance::Money Maintenance::CashCounts Maintenance::Expenses
    Maintenance::SingleFarm Maintenance::PlotsFromLots
  ].freeze

  def self.tasks = TASKS.map(&:constantize)
  def self.find(key) = tasks.find { |task| task.key == key.to_s }
  def self.find_by_slug(slug) = tasks.find { |task| task.slug == slug.to_s }

  # One part of what a run found: a title, how it looks (ok / warn / bad)
  # and its lines, already in Spanish.
  Section = Data.define(:title, :status, :lines) do
    def self.from_h(hash) = new(title: hash["title"], status: hash["status"], lines: Array(hash["lines"]))
    def to_h = { "title" => title, "status" => status, "lines" => lines }
  end

  STATUS_ORDER = %w[ok warn bad failed].freeze

  # The worst status of some sections.
  def self.worst(statuses) = statuses.max_by { STATUS_ORDER.index(it) || 0 } || "ok"
end
