# Data maintenance tasks (Maintenance, Fernando, 2026-11-15), from the
# Render shell. The same ones run from Administración → Mantenimiento de
# datos (only User::DATA_EXPORTER_ID). Each run is kept (MaintenanceRun).
#
#   bin/rails integrity:check                          # reads only: what does not add up
#   bin/rails batches:backfill FROM=2026-09-01 TO=2026-11-15   # preview: changes nothing
#   CONFIRM=1 bin/rails batches:backfill FROM=…        # does it, all or nothing
#   bin/rails maintenance:runs                         # the last runs
#   bin/rails "maintenance:revert[RUN_ID]"             # undoes a run that changed data
#
# Options by ENV: FROM, TO (dates, AAAA-MM-DD), DAYS, CATEGORY_IDS (1,2,3).
module MaintenanceRake
  def self.print(run)
    puts "#{run.task.title} · #{run.mode_label} · #{I18n.t("maintenance.statuses.#{run.status}")} · corrida #{run.id} (#{run.duration_ms} ms)"
    puts "Error: #{run.error}" if run.failed?
    run.section_list.each do |section|
      puts "", "[#{I18n.t("maintenance.statuses.#{section.status}")}] #{section.title}"
      section.lines.each { puts "  #{it}" }
    end
    return unless run.task.changes_data?

    puts ""
    puts run.apply? ? "Para deshacerla: bin/rails \"maintenance:revert[#{run.id}]\"" : "No cambió nada. Para aplicarla: CONFIRM=1 bin/rails #{run.task_key} (mismas opciones)."
  end

  def self.with_request_id
    Current.set(request_id: "maintenance-#{SecureRandom.hex(4)}") { yield }
  end
end

# The tasks (Maintenance::TASKS), listed here because the app is not
# loaded until a task runs; a spec checks both lists match.
MAINTENANCE_TASKS = {
  "integrity:check" => "Revisión completa: ¿todo cuadra? (solo revisa)",
  "integrity:inventory" => "Cuadre del inventario de café (solo revisa)",
  "integrity:shipments" => "Salidas incompletas (solo revisa)",
  "integrity:shipment_expense_candidates" => "Gastos que parecen de un viaje (solo revisa; DAYS, CATEGORY_IDS)",
  "batches:backfill" => "Armar lotes para las salidas pasadas (FROM, TO; CONFIRM=1 aplica)",
  "integrity:sales" => "Ventas que no cuadran con sus salidas (solo revisa)",
  "sales:recalculate" => "Recalcular las ventas que no cuadran con sus salidas (CONFIRM=1 aplica)",
  "integrity:money" => "Cuadre del dinero (solo revisa)",
  "integrity:cash_counts" => "Arqueos que ya no cuadran (solo revisa)",
  "integrity:expenses" => "Gastos por revisar (solo revisa)",
  "purchases:assign_single_farm" => "Finca de las compras de productores con una sola finca (CONFIRM=1 aplica)",
  "farms:plots_from_lots" => "Los «Lote 1», «Lote 2»… pasan a ser parcelas de una finca con el nombre de su lugar (CONFIRM=1 aplica)"
}.freeze

MAINTENANCE_TASKS.each do |key, description|
  scope, name = key.split(":")
  namespace scope do
    desc description
    task name => :environment do
      task = Maintenance.find(key)
      run = MaintenanceRake.with_request_id do
        Maintenance::Runner.run(task, params: ENV.to_h, apply: ENV["CONFIRM"] == "1")
      end
      MaintenanceRake.print(run)
      exit 1 if run.failed?
    end
  end
end

namespace :maintenance do
  desc "Lists the last runs of the data maintenance tasks"
  task runs: :environment do
    MaintenanceRun.newest_first.limit(30).each do |run|
      puts [ run.id, run.created_at.in_time_zone.strftime("%d/%m/%Y %H:%M"), run.task_key, run.mode_label,
             I18n.t("maintenance.statuses.#{run.status}"), run.who, (run.reverted? ? "deshecha" : nil) ].compact.join("  ")
    end
  end

  desc "Undoes a run that changed data: bin/rails \"maintenance:revert[RUN_ID]\""
  task :revert, [ :run_id ] => :environment do |_task, args|
    run = MaintenanceRun.find_by(id: args[:run_id])
    abort "No existe la corrida #{args[:run_id]}." unless run
    abort "Esa corrida no cambió datos o ya se deshizo." unless run.revertible?

    revert = MaintenanceRake.with_request_id { Maintenance::Runner.revert(run) }
    MaintenanceRake.print(revert)
  end
end
