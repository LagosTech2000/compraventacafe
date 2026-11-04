require "rails_helper"

# Subcategories of the farms' expense categories (Fernando, 2026-11-03).
RSpec.describe "Farms expense subcategories" do
  let(:admin) { create(:user, :admin) }
  let(:payroll) { create(:payroll, starts_on: Time.zone.today - 10) }
  let(:transport) { create(:expense_category, name: "Transporte") }
  let(:fuel) { create(:expense_category, name: "Combustible", parent: transport) }

  def page = Nokogiri::HTML(response.body)

  before { sign_in admin }

  it "adds a subcategory from its first level, audited" do
    transport
    get farms_expense_categories_path
    link = page.css("##{ActionView::RecordIdentifier.dom_id(transport)} a").find { it.text == "Agregar subcategoría" }
    expect(link["href"]).to eq(new_farms_expense_category_path(parent_id: transport.id))

    get link["href"]
    expect(page.at_css("select#expense_category_parent_id option[selected]")&.text).to eq("Transporte")

    post farms_expense_categories_path, params: { expense_category: { name: "Combustible", parent_id: transport.id } }
    category = ExpenseCategory.find_by!(name: "Combustible")
    expect(category.parent).to eq(transport)
    expect(AuditEvent.where(auditable: category, action: "create").last.auditable_label).to eq("Transporte › Combustible")

    get farms_expense_categories_path
    row = page.at_css("##{ActionView::RecordIdentifier.dom_id(category)}")
    expect(row.text).to include("Transporte", "› Combustible")
  end

  it "rejects a third level" do
    post farms_expense_categories_path, params: { expense_category: { name: "Diésel", parent_id: fuel.id } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("debe ser una categoría de primer nivel")
  end

  it "finds a subcategory by its first level's name" do
    fuel
    create(:expense_category, name: "Herramientas")

    get farms_expense_categories_path(q: "transp")
    expect(page.css("tbody tr").map { it["id"] }).to contain_exactly(
      ActionView::RecordIdentifier.dom_id(transport), ActionView::RecordIdentifier.dom_id(fuel))
  end

  it "records an expense with a subcategory, shows its full name and filters by its first level" do
    fuel
    get new_farms_payroll_expense_path(payroll)
    expect(page.css("#payroll_expense_expense_category_id option").map(&:text)).to include("Transporte", "Transporte › Combustible")

    post farms_payroll_expenses_path(payroll), params: { payroll_expense: { spent_on: Time.zone.today, expense_category_id: fuel.id,
                                                                            description: "Diésel del pickup", amount: "500" } }
    create(:payroll_expense, payroll:, description: "Machetes", category: create(:expense_category, name: "Herramientas"))

    get farms_payroll_path(payroll, tab: "expenses", expense_category_id: transport.id)
    expect(response.body).to include("Transporte › Combustible", "Diésel del pickup")
    expect(response.body).not_to include("Machetes")

    get farms_payroll_path(payroll, tab: "expenses", expense_category_id: fuel.id)
    expect(response.body).to include("Diésel del pickup")
  end

  it "reports by first level and by subcategory, and a first level brings its subcategories" do
    today = Time.zone.today
    create(:payroll_expense, payroll:, spent_on: today, category: fuel, amount: 300)
    create(:payroll_expense, payroll:, spent_on: today, category: transport, amount: 100)
    create(:payroll_expense, payroll:, spent_on: today, category: create(:expense_category, name: "Herramientas"), amount: 50)

    report = ->(**params) { PayrollExpensesReport.new({ period: "this_month", **params }, user: admin) }
    by_category = report.(group: "category", measure: "amount").page.first.to_h { [ it.label, it["amount"] ] }
    expect(by_category).to eq("Transporte" => 400, "Herramientas" => 50)
    by_subcategory = report.(group: "subcategory", measure: "amount").page.first.to_h { [ it.label, it["amount"] ] }
    expect(by_subcategory).to eq("Transporte › Combustible" => 300, "Transporte" => 100, "Herramientas" => 50)
    expect(report.(category_id: transport.id).total_count).to eq(2)
    expect(report.(category_id: fuel.id).total_count).to eq(1)

    get reports_report_path("payroll_expenses", period: "this_month")
    expect(response.body).to include("Transporte › Combustible")
  end

  it "shows the full name in the money movements" do
    create(:payroll_expense, payroll:, category: fuel)

    movement = MoneyMovements.new.all.find { it.source == "payroll_expenses" }
    expect(movement.category).to eq("Transporte › Combustible")
  end
end
