require "rails_helper"

# Farms on screen: attendance marked by tapping (timesheet_controller.js)
# with its save bar (unsaved_changes_controller.js), today's work from the
# module home, and the payrolls and periods filtered without reloading.
RSpec.describe "Farms screens", type: :system do
  let(:user) { create(:user, :admin) }
  let(:today) { Time.zone.today }
  let(:payroll) { create(:payroll, name: "Limpia", starts_on: today.beginning_of_week - 14) }
  let!(:ana) { create(:payroll_member, payroll:, person: create(:person, :collaborator, first_names: "Ana", last_names: "Zelaya")) }
  let!(:bruno) { create(:payroll_member, payroll:, person: create(:person, :collaborator, first_names: "Bruno", last_names: "Aguilar")) }

  def mark_page = page.execute_script("document.body.dataset.pageMarker = 'still here'")
  def page_reloaded? = page.evaluate_script("document.body.dataset.pageMarker") != "still here"

  before { sign_in_as(user) }

  it "marks attendance by tapping each day, fills a whole period, and saves from the bar" do
    period = payroll.period_containing(today)
    visit farms_payroll_timesheet_path(payroll, period: period.to_param)
    expect(page).to have_css(".save-bar", text: "Sin cambios por guardar.")

    toggle = find("button.day-toggle[aria-label^='Ana Zelaya, #{I18n.l(period.starts_on, format: :long)}']")
    toggle.click
    expect(toggle).to have_text("1")
    toggle.click
    expect(toggle).to have_text("½")
    expect(page).to have_css(".save-bar", text: "Tienes cambios sin guardar.")

    bruno_row = find("tr", text: "Bruno Aguilar")
    bruno_days = bruno_row.all("button.day-toggle").size
    within(bruno_row) { click_button "Todo el período" }
    expect(find("tr", text: "Bruno Aguilar")).to have_css("button.day-toggle[data-state='1']", count: bruno_days)

    within(".save-bar") { click_button "Guardar" }
    expect(page).to have_text("Guardado.")
    expect(ana.attendances.sum(:day_fraction)).to eq(0.5)
    expect(bruno.attendances.sum(:day_fraction)).to eq(bruno_days)
  end

  it "takes cans by quarters, and says so in Spanish before sending" do
    harvest = create(:payroll, name: "Corte", kind: "harvest", can_price: 40, starts_on: today)
    picker = create(:payroll_member, payroll: harvest, person: create(:person, :collaborator, first_names: "Carla", last_names: "Mejía"))
    visit farms_payroll_timesheet_path(harvest)

    cell = find("input[name='work[#{picker.id}][#{today.iso8601}]']")
    cell.fill_in(with: "2.3")
    within(".save-bar") { click_button "Guardar" }
    expect(cell.evaluate_script("this.validationMessage")).to eq("Latas de cuarto en cuarto: 0.25, 0.50, 0.75, 1.00, 1.25…")
    expect(picker.harvest_entries).to be_empty

    cell.fill_in(with: "2.75")
    within(".save-bar") { click_button "Guardar" }
    expect(page).to have_text("Guardado.")
    expect(picker.harvest_entries.sole.cans).to eq(2.75)
  end

  it "asks before leaving with changes not saved" do
    visit farms_payroll_timesheet_path(payroll, period: payroll.period_containing(today).to_param)
    first("button.day-toggle").click

    message = dismiss_confirm { within(".subnav") { click_link "Planillas" } }
    expect(message).to eq("Tienes cambios sin guardar en esta planilla. ¿Salir sin guardar?")
    expect(page).to have_css("h1", text: "Asistencia")

    accept_confirm { within(".subnav") { click_link "Planillas" } }
    expect(page).to have_css("h1", text: "Planillas")
  end

  it "goes from the module home to today's attendance in one tap" do
    payroll
    visit farms_root_path
    within("#card_payroll_#{payroll.id}") { click_link "Asistencia de hoy" }
    expect(page).to have_css("h1", text: "Asistencia")
    expect(page).to have_css(".nav-pill-active", text: I18n.l(today, format: :short_day))
  end

  it "filters payrolls and their periods without reloading the page" do
    create(:payroll, name: "Corte grande", kind: "harvest", starts_on: today - 3)
    visit farms_payrolls_path
    mark_page
    expect(page).to have_text("2 planillas")

    select "Corte de café (por lata)", from: "kind"
    expect(page).to have_text("1 planilla")
    expect(page).to have_css(".chip-filter", text: "Corte de café (por lata)")

    visit farms_payroll_path(payroll)
    mark_page
    expect(page).to have_css("#current-period")
    click_link "Próximos"
    expect(page).to have_css(".chip-active", text: "Próximos")
    expect(all("#periods-list tbody tr").map { |row| row.text }).to all(include("Próximo"))
    expect(page_reloaded?).to be(false)
  end

  it "opens a payroll from the lists, and its timesheet from the periods, as whole pages" do
    payroll
    visit farms_payrolls_path
    within("#payrolls-list") { click_link "Abrir", match: :first }
    expect(page).to have_css("h1", text: "Limpia")
    expect(page).to have_no_text("Content missing")

    within("#periods-list") { click_link "Asistencia", match: :first }
    expect(page).to have_css("h1", text: "Asistencia")
    expect(page).to have_no_text("Content missing")

    visit farms_farm_path(payroll.farm)
    within("#payrolls-list") { click_link "Abrir" }
    expect(page).to have_css("h1", text: "Limpia")
  end

  it "goes farm → payroll → attendance and back up by the route, the tabs without reloading" do
    farm = payroll.farm
    visit farms_farms_path
    find("#farms-list tr", text: farm.name).click # the whole row opens the farm, as a page
    expect(page).to have_css("h1", text: farm.name)
    expect(page).to have_css("nav[aria-label='Dónde estás']", text: "Fincas")
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_no_css("#payrolls-list th", text: "FINCA") # every payroll here is this farm's

    within("#payrolls-list") { click_link "Abrir" }
    expect(page).to have_css("h1", text: "Limpia")
    within("nav[aria-label='Dónde estás']") { expect(page).to have_link(farm.name) }
    mark_page
    click_link "Empleados"
    expect(page).to have_css("#payroll-members")
    expect(page).to have_current_path(/tab=members/)
    expect(page_reloaded?).to be(false)
    click_link "Gastos"
    expect(page).to have_current_path(/tab=expenses/)
    expect(page_reloaded?).to be(false)

    click_link "Asistencia de hoy"
    expect(page).to have_css("h1", text: "Asistencia")
    expect(page).to have_css("nav[aria-label='Dónde estás'] [aria-current=page]", text: "Asistencia")
    click_link "Ver la planilla"
    expect(page).to have_css("h1", text: "Limpia")

    within("nav[aria-label='Dónde estás']") { click_link farm.name }
    expect(page).to have_css("h1", text: farm.name)
    within("nav[aria-label='Dónde estás']") { click_link "Fincas" }
    expect(page).to have_css("h1", text: "Fincas")
  end

  it "picks the task's people at once and shows how many and each one's part" do
    task_payroll = create(:payroll, kind: "task", starts_on: today - 10)
    3.times { create(:payroll_member, payroll: task_payroll) }
    visit new_farms_payroll_task_path(task_payroll)
    fill_in "payroll_task_amount", with: "900"

    click_button "Todos"
    expect(page).to have_text("3 personas · Le toca a cada uno: L 300.00")
    click_button "Ninguno"
    expect(page).to have_text("0 personas")
    first("input[name='payroll_task[member_ids][]'][type=checkbox]").check
    expect(page).to have_text("1 persona · Le toca a cada uno: L 900.00")
  end

  it "filters the payroll's people as the user goes" do
    bruno.update!(active: false)
    visit farms_payroll_path(payroll, tab: "members")
    mark_page
    expect(page).to have_text("1 empleado")
    expect(page).to have_css(".badge", text: "Activo")

    select "Inactivos", from: "status"
    expect(page).to have_text("Bruno Aguilar")
    expect(page).to have_css(".badge", text: "Inactivo")
    expect(page_reloaded?).to be(false)
  end

  it "keeps the date, totals and button of a payment in view on the right" do
    period = payroll.periods.first
    PayrollTimesheet.new(payroll, period).update(ana.id.to_s => { period.starts_on.iso8601 => "1" })
    visit new_farms_payroll_payment_path(payroll, period: period.to_param)
    left = ->(selector) { page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().left") }
    expect(left.call("aside")).to be > left.call("#pay-lines") + 400
    expect(page).to have_css("aside [type=submit][value='Registrar pago']")
  end

  it "creates a farm for a producer from the farms module, and a producer with several farms" do
    producer = create(:producer, person: create(:person, first_names: "Ana", last_names: "Zelaya"))
    visit new_farms_farm_path
    fill_in "farm_name", with: "El Mirador"
    fill_in "farm_producer_search", with: producer.picker_label
    within("main form") { find("[type=submit]").click }
    expect(page).to have_text("Finca registrada.")
    expect(producer.farms.pluck(:name)).to eq([ "El Mirador" ])

    visit new_trading_producer_path
    fill_in "producer_person_attributes_first_names", with: "Bruno"
    fill_in "producer_person_attributes_last_names", with: "Aguilar"
    # A dropdown with its farms and «Agregar finca» (Fernando, 2026-10-13).
    expect(page).to have_select("Fincas del productor", options: [ "Sin fincas todavía" ])
    add_farm = lambda do |name|
      click_button "Agregar finca"
      within("dialog[open]") do
        fill_in "Nombre de la finca", with: name
        click_button "Agregar"
      end
      expect(page).to have_no_css("dialog[open]")
    end
    click_button "Agregar finca"
    within("dialog[open]") { click_button "Agregar" } # a name is needed
    expect(page).to have_css("dialog[open] [role=alert]", text: "Nombre de la finca no puede estar en blanco")
    within("dialog[open]") { click_button "Cancelar" }
    add_farm.call("Las Brisas")
    add_farm.call("Santa Rosa")
    add_farm.call("El Error")
    add_farm.call(" las  brisas ") # already in the list: chosen, not repeated
    expect(page).to have_select("Fincas del productor", options: [ "Las Brisas (nueva)", "Santa Rosa (nueva)", "El Error (nueva)" ],
                                                        selected: "Las Brisas (nueva)")
    select "El Error (nueva)", from: "Fincas del productor"
    click_button "Quitar esta"
    expect(page).to have_select("Fincas del productor", options: [ "Las Brisas (nueva)", "Santa Rosa (nueva)" ])

    # Enter in the window adds; it never sends the producer's form.
    click_button "Agregar finca"
    within("dialog[open]") { find_field("Nombre de la finca").send_keys("La Cumbre", :enter) }
    expect(page).to have_select("Fincas del productor", with_options: [ "La Cumbre (nueva)" ])
    expect(page).to have_current_path(new_trading_producer_path)

    within("main form") { find("[type=submit]").click }
    expect(page).to have_text("Productor creado.")
    expect(Producer.last.farm_names).to eq("La Cumbre, Las Brisas, Santa Rosa")

    visit edit_trading_producer_path(Producer.last)
    expect(page).to have_select("Fincas del productor", options: [ "La Cumbre", "Las Brisas", "Santa Rosa" ])
    expect(page).to have_button("Quitar esta", visible: :hidden) # saved farms are not taken out here
  end

  it "calculates the land in the other units from the one typed, and saves that one" do
    visit new_farms_farm_path
    fill_in "farm_name", with: "El Cerro"
    fill_in "Manzanas", with: "10"
    expect(page).to have_field("Hectáreas", with: "6.99")
    expect(page).to have_field("Metros cuadrados (m²)", with: "69890")
    expect(page).to have_text("Se guarda como la escribiste, en Manzanas.")

    fill_in "Hectáreas", with: "2"
    expect(page).to have_field("Manzanas", with: "2.86")
    expect(page).to have_field("Metros cuadrados (m²)", with: "20000")
    expect(page).to have_text("Se guarda como la escribiste, en Hectáreas.")

    # Emptying the one typed empties them all: no land.
    fill_in "Hectáreas", with: ""
    expect(page).to have_field("Manzanas", with: "")
    expect(page).to have_field("Metros cuadrados (m²)", with: "")

    fill_in "Hectáreas", with: "2"
    within("main form") { find("[type=submit]").click }
    expect(page).to have_text("Finca registrada.")
    expect(Farm.find_by!(name: "El Cerro")).to have_attributes(area_value: 2, area_unit: "hectare")

    visit edit_farms_farm_path(Farm.find_by!(name: "El Cerro"))
    expect(page).to have_field("Hectáreas", with: "2")
    expect(page).to have_field("Manzanas", with: "2.86")
    expect(page).to have_field("Metros cuadrados (m²)", with: "20000")
  end

  it "takes the period's extra hours and days at the end of each row, adding them to the pay before saving" do
    payroll.update!(overtime_hour_rate: 50)
    period = payroll.period_containing(today)
    visit farms_payroll_timesheet_path(payroll, period: period.to_param)

    row = find("tr", text: "Ana Zelaya")
    within(row) do
      fill_in "Ana Zelaya, horas extra del período", with: "2"
      expect(page).to have_css("[data-timesheet-target='rowAmount']", text: "L 100.00")
      fill_in "Ana Zelaya, días extra del período", with: "1"
      expect(page).to have_css("[data-timesheet-target='rowAmount']", text: "L 400.00") # 1 × L 300 + 2 h × L 50
    end
    expect(page).to have_css("[data-timesheet-target='overtimeTotal'][data-overtime='hours']", text: "2")
    expect(page).to have_css(".save-bar", text: "Tienes cambios sin guardar.")
    click_button "Guardar"
    expect(page).to have_text("Guardado")
    expect(ana.overtimes.sole).to have_attributes(period_starts_on: period.starts_on, hours: 2, extra_days: 1)

    # Emptying both removes it.
    within(find("tr", text: "Ana Zelaya")) do
      fill_in "Ana Zelaya, horas extra del período", with: ""
      fill_in "Ana Zelaya, días extra del período", with: ""
    end
    click_button "Guardar"
    expect(page).to have_text("Guardado")
    expect(ana.overtimes.reload).to be_empty
  end

  it "keeps extra hours closed until the payroll has the value of an extra hour" do
    visit farms_payroll_timesheet_path(payroll, period: payroll.period_containing(today).to_param)
    expect(page).to have_field("Ana Zelaya, horas extra del período", disabled: true)
    expect(page).to have_field("Ana Zelaya, días extra del período", disabled: false)
    expect(page).to have_text("define primero el valor de la hora extra en la planilla")
    expect(page).to have_link("Definir el valor de la hora extra")
  end

  it "lines up each day's cell with its heading and its total" do
    harvest = create(:payroll, kind: "harvest", can_price: 25, starts_on: today.beginning_of_week - 7)
    create_list(:payroll_member, 2, payroll: harvest)
    [ [ harvest, "input[data-date]" ], [ payroll, "button.day-toggle" ] ].each do |sheet, cell|
      visit farms_payroll_timesheet_path(sheet, period: sheet.period_containing(today).to_param)
      offsets = page.evaluate_script(<<~JS)
        (() => {
          const table = document.querySelector(".timesheet-grid")
          const center = (el) => { const r = el.getBoundingClientRect(); return r.left + r.width / 2 }
          const heads = [...table.querySelectorAll("thead th")].slice(1)
          return [...table.querySelectorAll("tbody tr")].flatMap((row) =>
            [...row.querySelectorAll("#{cell}")].map((input, index) => Math.abs(center(input) - center(heads[index]))))
        })()
      JS
      expect(offsets).not_to be_empty
      expect(offsets.max).to be < 1.5
    end
  end

  it "asks the value of an extra hour for payrolls by day and harvest, not by task" do
    visit new_farms_payroll_path(farm_id: payroll.farm_id)
    choose "Por día"
    expect(page).to have_field("Valor de la hora extra (L)")
    choose "Por obra (tarea)"
    expect(page).to have_no_field("Valor de la hora extra (L)")
    choose "Corte de café (por lata)"
    fill_in "Nombre", with: "Corte grande"
    fill_in "Precio de la lata (L)", with: "25"
    fill_in "Valor de la hora extra (L)", with: "45"
    within("main form") { find("[type=submit]").click }
    expect(page).to have_text("Corte grande")
    expect(Payroll.find_by!(name: "Corte grande")).to have_attributes(overtime_hour_rate: 45, can_price: 25)
  end
end
