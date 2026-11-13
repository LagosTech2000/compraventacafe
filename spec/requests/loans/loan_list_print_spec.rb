require "rails_helper"

# Préstamos → Préstamos (Fernando, 2026-11-12): filter by the person's zone,
# totals of everything filtered, the filtered list printed with its totals,
# and Cartera por zona opening the list with that zone.
RSpec.describe "Loans list: zone, totals and printing" do
  let(:admin) { create(:user, :admin) }
  let(:today) { Time.zone.today }
  let(:moroceli) { create(:zone, name: "Morocelí") }
  let(:danli) { create(:zone, name: "Danlí") }

  def page = Nokogiri::HTML(response.body)
  def totals = page.css("[data-loan-totals] [data-total]").to_h { [ it["data-total"], it.at_css("dd").text.strip ] }
  def listed = page.css("tbody tr[id^='loan_']").map { it["id"] }

  let!(:ana) { create(:loan, person: create(:person, first_names: "Ana", last_names: "Zelaya", zone: moroceli), cash_amount: 1_000, monthly_interest_rate: 0) }
  let!(:beto) { create(:loan, person: create(:person, first_names: "Beto", last_names: "Lara", zone: moroceli), cash_amount: 500, monthly_interest_rate: 0) }
  let!(:carla) { create(:loan, person: create(:person, first_names: "Carla", last_names: "Paz", zone: danli), cash_amount: 2_000, monthly_interest_rate: 0) }
  let!(:dora) { create(:loan, person: create(:person, first_names: "Dora", last_names: "Ruiz"), cash_amount: 300, monthly_interest_rate: 0) }

  before do
    create(:loan_payment, loan: ana, amount: 200, payment_method: "cash")
    sign_in admin
  end

  it "filters by the person's zone, or the people without one" do
    get loans_loans_path(zone_id: moroceli.id)
    expect(listed).to contain_exactly("loan_#{ana.id}", "loan_#{beto.id}")
    expect(response.body).to include("Zona: Morocelí")

    get loans_loans_path(zone_id: "none")
    expect(listed).to eq([ "loan_#{dora.id}" ])
    expect(response.body).to include("Zona: Sin zona")

    get loans_loans_path(zone_id: "nada")
    expect(listed.size).to eq(4)
  end

  it "shows the totals of everything filtered only when it is filtered" do
    get loans_loans_path
    expect(page.at_css("[data-loan-totals]")).to be_nil

    get loans_loans_path(zone_id: moroceli.id)
    expect(totals).to eq("principal" => "L 1,500.00", "principal_paid" => "L 200.00", "interest_paid" => "L 0.00",
                         "principal_owed" => "L 1,300.00", "interest_owed" => "L 0.00", "total_owed" => "L 1,300.00")
    expect(page.at_css("[data-loan-totals]").text).to include("2 préstamos", "2 personas")
  end

  it "prints the filtered list with its filters and totals, from a button that follows the filters" do
    get loans_loans_path(zone_id: moroceli.id, status: "unpaid")
    link = page.css("a").find { it.text.strip == "Imprimir" }
    expect(link["href"]).to include(print_loans_loans_path, "zone_id=#{moroceli.id}", "status=unpaid", "print=1")

    get link["href"]
    expect(response).to have_http_status(:ok)
    expect(page.at_css("header.border-b-2").text).to include("Préstamos")
    expect(page.at_css("[data-print-filters]").text.squish).to include("Por cobrar", "Zona: Morocelí")
    expect(page.css("[data-print-loans] tbody tr").map { it.text.squish }).to contain_exactly(a_string_including("Ana Zelaya", "Morocelí"), a_string_including("Beto Lara"))
    expect(totals["total_owed"]).to eq("L 1,300.00")
    expect(page.at_css("[data-print-loans] tfoot").text.squish).to include("2 préstamos", "L 1,500.00", "L 200.00", "L 1,300.00")
    expect(page.at_css("[data-controller='print']")["data-print-auto-value"]).to eq("true")

    get print_loans_loans_path
    expect(page.at_css("[data-print-filters]").text).to include("Sin filtros")
    expect(page.css("[data-print-loans] tbody tr").size).to eq(4)
  end

  it "Cartera por zona opens the list with that zone's loans to collect" do
    create(:loan, person: ana.person, cash_amount: 100, monthly_interest_rate: 0).update_columns(paid_off_on: today)
    get loans_portfolio_path
    row = page.at_css("#portfolio-zone-#{moroceli.id}")
    href = row.at_css("a")["href"]
    expect(href).to eq(loans_loans_path(status: "unpaid", zone_id: moroceli.id))
    expect(page.at_css("#portfolio-zone-none a")["href"]).to eq(loans_loans_path(status: "unpaid", zone_id: "none"))

    get href
    expect(listed).to contain_exactly("loan_#{ana.id}", "loan_#{beto.id}")
  end

  it "takes seeing the loans" do
    sign_in create(:user).tap { create(:permission, user: it, module_key: "loans", submodule_key: "simulation", can_read: true) }
    get print_loans_loans_path
    expect(response).to redirect_to(root_path)
  end
end
