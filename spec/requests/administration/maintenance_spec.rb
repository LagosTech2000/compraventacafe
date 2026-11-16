require "rails_helper"

# Administración → Mantenimiento de datos (Fernando, 2026-11-15): only the
# user with User::DATA_EXPORTER_ID sees it; each task says what it does; a
# check runs at once, a task that changes data shows a preview first and
# is applied from it with the backup downloaded, and can be undone.
RSpec.describe "Data maintenance" do
  let(:exporter) { make_data_exporter(create(:user, :admin)) }

  def page = Nokogiri::HTML(response.body)

  it "is only for the user who exports the data, while an administrator" do
    sign_in create(:user, :admin)
    get administration_maintenance_tasks_path
    expect(flash[:alert]).to eq("No tienes permiso para hacer eso.")
    post administration_maintenance_runs_path, params: { slug: "integrity_money" }
    expect(MaintenanceRun.count).to eq(0)
    get administration_root_path
    expect(response.body).not_to include(administration_maintenance_tasks_path)

    sign_in exporter
    get administration_root_path
    expect(response.body).to include(administration_control_center_path)
  end

  it "lists every task with what it does, how it leaves the system and its command" do
    sign_in exporter
    get administration_maintenance_tasks_path
    cards = page.css("[data-maintenance-tasks] article")
    expect(cards.size).to eq(Maintenance.tasks.size)
    expect(cards.map { it.at_css("h3").text }).to include("Cuadre del dinero", "Armar lotes para las salidas pasadas")
    expect(response.body).to include("bin/rails integrity:check", "Cómo queda el sistema", "Necesita decisión del cliente")
  end

  it "runs a check and shows what it found" do
    sign_in exporter
    create(:money_account, name: "Caja", opening_balance: 0)
    get administration_maintenance_task_path("integrity_money")
    expect(response.body).to include("Revisar ahora")

    post administration_maintenance_runs_path, params: { slug: "integrity_money" }
    run = MaintenanceRun.last
    expect(response).to redirect_to(administration_maintenance_run_path(run))
    expect(run).to have_attributes(task_key: "integrity:money", mode: "preview", user: exporter)
    follow_redirect!
    expect(page.css("[data-maintenance-sections] li").map(&:text)).to include(a_string_including("Caja: saldo L 0.00"))
    expect(page.at_css("[data-maintenance-apply]")).to be_nil
  end

  it "applies a preview only with the backup downloaded, and undoes it" do
    sign_in exporter
    producer = create(:producer)
    farm = create(:farm, producer:)
    purchase = create(:purchase, producer:)

    post administration_maintenance_runs_path, params: { slug: "purchases_assign_single_farm" }
    preview = MaintenanceRun.last
    follow_redirect!
    expect(page.at_css("[data-maintenance-apply]")).to be_present
    expect(response.body).to include("CONFIRM=1 bin/rails purchases:assign_single_farm")

    post administration_maintenance_runs_path, params: { from_run_id: preview.id }
    expect(flash[:alert]).to eq("Primero descarga el respaldo y marca la casilla.")
    expect(purchase.reload.farm).to be_nil

    post administration_maintenance_runs_path, params: { from_run_id: preview.id, backup_confirmed: "1" }
    applied = MaintenanceRun.last
    expect(applied).to have_attributes(mode: "apply", status: "ok")
    expect(purchase.reload.farm).to eq(farm)
    follow_redirect!
    expect(response.body).to include("Cambios aplicados.", "Deshacer")

    post administration_maintenance_runs_path, params: { from_run_id: applied.id, backup_confirmed: "1" }
    expect(flash[:alert]).to eq("Solo se aplica desde una vista previa que no falló.")

    post revert_administration_maintenance_run_path(applied)
    expect(purchase.reload.farm).to be_nil
    expect(flash[:notice]).to eq("Cambios deshechos.")
    post revert_administration_maintenance_run_path(applied)
    expect(flash[:alert]).to eq("Esta corrida no cambió datos o ya se deshizo.")
  end

  it "runs from the shell too" do
    require "rake"
    Rails.application.load_tasks unless Rake::Task.task_defined?("integrity:expenses")
    create(:expense)
    expect { Rake::Task["integrity:expenses"].execute }.to output(/Gastos por revisar · Revisión · Por revisar · corrida \d+/).to_stdout
    expect(MaintenanceRun.last).to have_attributes(task_key: "integrity:expenses", user: nil)
    expect(MaintenanceRun.last.request_id).to start_with("maintenance-")
  end
end
